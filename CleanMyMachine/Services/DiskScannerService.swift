import Foundation

struct ScanProgress {
    let scannedFiles: Int
    let currentPath: String
    let totalSize: Int64
    let estimatedProgress: Double // 0.0–1.0, rough estimate based on disk size
}

/// Recursively scans a directory tree, building a FileSystemNode hierarchy.
/// Reports progress via AsyncStream during the scan.
actor DiskScannerService {

    static let shared = DiskScannerService()

    private let fileManager = FileManager.default
    private let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .fileSizeKey,
        .fileResourceIdentifierKey,
        .volumeURLKey,
    ]

    // MARK: - Public API

    func scan(
        url: URL,
        progress: @escaping @Sendable (ScanProgress) -> Void,
        onFolderScanned: (@Sendable (FileSystemNode) -> Void)? = nil
    ) async throws -> FileSystemNode {
        let diskTotal = (try? FileManager.default.attributesOfFileSystem(forPath: url.path))?[.systemSize] as? Int64 ?? 0
        let rootVolume = (try? url.resourceValues(forKeys: [.volumeURLKey]))?.volume

        var scannedFiles = 0
        var totalSize: Int64 = 0
        var seenInodes = Set<Data>()

        // Enumerate root's immediate children one-by-one so we can report each
        // folder as it completes (for the live bubble chart).
        let rootContents: [URL]
        do {
            rootContents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: []
            )
        } catch {
            return FileSystemNode(url: url, size: 0, isDirectory: true, children: [])
        }

        var rootChildren: [FileSystemNode] = []
        var rootSize: Int64 = 0

        for childURL in rootContents {
            try Task.checkCancellation()

            let childNode = try await scanNode(
                url: childURL,
                rootVolume: rootVolume,
                scannedFiles: &scannedFiles,
                totalSize: &totalSize,
                seenInodes: &seenInodes,
                diskTotal: diskTotal,
                progress: progress
            )
            rootChildren.append(childNode)
            rootSize += childNode.size

            if childNode.isDirectory && childNode.size > 0 {
                onFolderScanned?(childNode)
            }
        }

        let root = FileSystemNode(url: url, size: rootSize, isDirectory: true, children: rootChildren)
        root.computePercents()
        return root
    }

    // MARK: - Private

    private func scanNode(
        url: URL,
        rootVolume: URL?,
        scannedFiles: inout Int,
        totalSize: inout Int64,
        seenInodes: inout Set<Data>,
        diskTotal: Int64,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> FileSystemNode {

        let resourceValues = try? url.resourceValues(forKeys: resourceKeys)
        let isDirectory = resourceValues?.isDirectory ?? false
        let isSymlink = resourceValues?.isSymbolicLink ?? false
        let isPackage = resourceValues?.isPackage ?? false

        // Don't follow symlinks
        if isSymlink {
            return FileSystemNode(url: url, size: 0, isDirectory: false)
        }

        // Files and packages: count once per inode to avoid hard-link inflation
        if !isDirectory || isPackage {
            if let inodeRef = resourceValues?.fileResourceIdentifier,
               let inodeData = try? NSKeyedArchiver.archivedData(withRootObject: inodeRef, requiringSecureCoding: false) {
                if seenInodes.contains(inodeData) {
                    return FileSystemNode(url: url, size: 0, isDirectory: isPackage)
                }
                seenInodes.insert(inodeData)
            }

            let size = Int64(resourceValues?.fileSize ?? 0)
            scannedFiles += 1
            totalSize += size

            if scannedFiles % 500 == 0 {
                let estimated = diskTotal > 0 ? min(0.99, Double(totalSize) / Double(diskTotal)) : 0
                progress(ScanProgress(
                    scannedFiles: scannedFiles,
                    currentPath: url.lastPathComponent,
                    totalSize: totalSize,
                    estimatedProgress: estimated
                ))
                await Task.yield()
            }

            return FileSystemNode(url: url, size: size, isDirectory: isPackage)
        }

        // Skip directories on a different volume (Dropbox, Google Drive, iCloud mounts, etc.)
        if let rootVolume, let nodeVolume = resourceValues?.volume, nodeVolume != rootVolume {
            return FileSystemNode(url: url, size: 0, isDirectory: true, children: [])
        }

        // Directory — list and recurse
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: []
            )
        } catch {
            return FileSystemNode(url: url, size: 0, isDirectory: true, children: [])
        }

        var children: [FileSystemNode] = []
        var dirSize: Int64 = 0

        for childURL in contents {
            try Task.checkCancellation()

            let childNode = try await scanNode(
                url: childURL,
                rootVolume: rootVolume,
                scannedFiles: &scannedFiles,
                totalSize: &totalSize,
                seenInodes: &seenInodes,
                diskTotal: diskTotal,
                progress: progress
            )
            children.append(childNode)
            dirSize += childNode.size
        }

        return FileSystemNode(url: url, size: dirSize, isDirectory: true, children: children)
    }
}
