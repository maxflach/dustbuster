import Foundation

enum CleanupError: LocalizedError {
    case deletionFailed(URL, Error)
    case dockerUnavailable

    var errorDescription: String? {
        switch self {
        case .deletionFailed(let url, let underlying):
            return "Failed to delete \(url.lastPathComponent): \(underlying.localizedDescription)"
        case .dockerUnavailable:
            return "Docker is not running or not installed"
        }
    }
}

/// Calculates sizes for cleanup categories and performs deletion.
actor CleanupService {

    static let shared = CleanupService()

    private let fileManager = FileManager.default

    // MARK: - Scanning

    /// Scan all categories and return results. Calls `onProgress` after each category.
    func scan(
        categories: [CleanupCategory] = CleanupCategory.allCases,
        onProgress: @escaping @Sendable (CleanupCategory) -> Void
    ) async -> [CleanupCategoryResult] {
        var results: [CleanupCategoryResult] = []

        for category in categories {
            onProgress(category)
            let result: CleanupCategoryResult
            if category.isDocker {
                result = await scanDocker()
            } else {
                result = await scanFilesystem(category: category)
            }
            results.append(result)
        }

        return results
    }

    private func scanFilesystem(category: CleanupCategory) async -> CleanupCategoryResult {
        var items: [CleanupItem] = []

        for baseURL in category.paths {
            guard fileManager.fileExists(atPath: baseURL.path) else { continue }

            // For trash and browser caches, enumerate top-level items
            // For system caches and logs, collect each top-level entry
            let children = (try? fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .totalFileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for childURL in children {
                let size = await calculateSize(of: childURL)
                if size > 0 {
                    items.append(CleanupItem(url: childURL, size: size))
                }
            }
        }

        return CleanupCategoryResult(category: category, items: items)
    }

    func calculateSize(of url: URL) async -> Int64 {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .totalFileSizeKey, .fileSizeKey])
        let isDir = resourceValues?.isDirectory ?? false

        if !isDir {
            return Int64(resourceValues?.totalFileSize ?? resourceValues?.fileSize ?? 0)
        }

        // For directories, walk and sum
        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if res?.isDirectory != true {
                total += Int64(res?.fileSize ?? 0)
            }
        }
        return total
    }

    // MARK: - Docker

    private func findDocker() -> String? {
        ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/usr/bin/docker"]
            .first { fileManager.fileExists(atPath: $0) }
    }

    private func scanDocker() async -> CleanupCategoryResult {
        guard let docker = findDocker() else {
            return CleanupCategoryResult(category: .docker)
        }

        var resources: [DockerResource] = []

        // Images
        if let out = runCommand(docker, arguments: ["image", "ls", "-a", "--format", "{{json .}}"]) {
            for line in out.split(separator: "\n").map(String.init) {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                let id       = String((json["ID"] as? String ?? "").prefix(12))
                let repo     = json["Repository"] as? String ?? ""
                let tag      = json["Tag"] as? String ?? ""
                let size     = parseDockerSize(json["Size"] as? String ?? "")
                let dangling = repo == "<none>" && tag == "<none>"
                let name     = dangling ? "<dangling image>" : "\(repo):\(tag)"

                resources.append(DockerResource(
                    id: id, kind: .image, name: name, size: size,
                    isOrphan: dangling,
                    status: dangling ? "Dangling" : "In use",
                    isSelected: dangling
                ))
            }
        }

        // Containers
        if let out = runCommand(docker, arguments: ["container", "ls", "-a", "--format", "{{json .}}"]) {
            for line in out.split(separator: "\n").map(String.init) {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                let id      = String((json["ID"] as? String ?? "").prefix(12))
                let name    = json["Names"] as? String ?? id
                let status  = json["Status"] as? String ?? ""
                let stopped = status.lowercased().hasPrefix("exited") || status.lowercased().hasPrefix("created")

                resources.append(DockerResource(
                    id: id, kind: .container, name: name, size: 0,
                    isOrphan: stopped,
                    status: stopped ? "Stopped" : "Running",
                    isSelected: stopped
                ))
            }
        }

        // Volumes — split into unused vs in-use
        let unusedVolumes = Set(
            (runCommand(docker, arguments: ["volume", "ls", "-f", "dangling=true", "-q"]) ?? "")
                .split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        )
        let allVolumes = (runCommand(docker, arguments: ["volume", "ls", "-q"]) ?? "")
            .split(separator: "\n").map(String.init).filter { !$0.isEmpty }

        for name in allVolumes {
            let unused = unusedVolumes.contains(name)
            resources.append(DockerResource(
                id: name, kind: .volume, name: name, size: 0,
                isOrphan: unused,
                status: unused ? "Unused" : "In use",
                isSelected: unused
            ))
        }

        // Build cache — size from docker system df
        if let dfOut = runCommand(docker, arguments: ["system", "df"]) {
            for line in dfOut.split(separator: "\n").map(String.init) {
                if line.lowercased().contains("build cache") {
                    let size = parseReclaimableSize(from: line)
                    if size > 0 {
                        resources.append(DockerResource(
                            id: "build-cache", kind: .buildCache,
                            name: "Build Cache", size: size,
                            isOrphan: true, status: "Reclaimable",
                            isSelected: true
                        ))
                    }
                    break
                }
            }
        }

        return CleanupCategoryResult(category: .docker, dockerResources: resources)
    }

    private func parseDockerSize(_ s: String) -> Int64 {
        let pattern = #"([\d.]+)\s*(B|kB|MB|GB|TB)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let valRange = Range(match.range(at: 1), in: s),
              let unitRange = Range(match.range(at: 2), in: s)
        else { return 0 }
        let value = Double(s[valRange]) ?? 0
        let unit  = s[unitRange].lowercased()
        let mults: [String: Double] = ["b": 1, "kb": 1_000, "mb": 1_000_000, "gb": 1_000_000_000, "tb": 1_000_000_000_000]
        return Int64(value * (mults[unit] ?? 1))
    }

    private func parseReclaimableSize(from line: String) -> Int64 {
        // Matches the reclaimable field like "800MB (66%)" or "3.449GB"
        let pattern = #"([\d.]+)\s*(B|kB|MB|GB|TB)\s+\("#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let valRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line)
        else { return parseDockerSize(line) }   // fallback: try total size
        let value = Double(line[valRange]) ?? 0
        let unit  = line[unitRange].lowercased()
        let mults: [String: Double] = ["b": 1, "kb": 1_000, "mb": 1_000_000, "gb": 1_000_000_000, "tb": 1_000_000_000_000]
        return Int64(value * (mults[unit] ?? 1))
    }

    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch { return nil }
    }

    // MARK: - Cleaning

    func clean(
        results: [CleanupCategoryResult],
        onProgress: @escaping @Sendable (URL) -> Void
    ) async -> (bytesFreed: Int64, errors: [CleanupError]) {
        var bytesFreed: Int64 = 0
        var errors: [CleanupError] = []

        for result in results where result.isSelected {
            if result.category.isDocker {
                bytesFreed += await cleanDockerResources(result.dockerResources)
                continue
            }
            for item in result.items where item.isSelected {
                onProgress(item.url)
                do {
                    try fileManager.removeItem(at: item.url)
                    bytesFreed += item.size
                } catch {
                    errors.append(.deletionFailed(item.url, error))
                }
            }
        }
        return (bytesFreed, errors)
    }

    private func cleanDockerResources(_ resources: [DockerResource]) async -> Int64 {
        guard let docker = findDocker() else { return 0 }
        var freed: Int64 = 0
        let selected = resources.filter(\.isSelected)

        // Stop & remove containers first (images may depend on them)
        let containerIds = selected.filter { $0.kind == .container }.map(\.id)
        if !containerIds.isEmpty {
            _ = runCommand(docker, arguments: ["container", "rm", "-f"] + containerIds)
        }

        // Remove images
        let imageIds = selected.filter { $0.kind == .image }.map(\.id)
        if !imageIds.isEmpty {
            _ = runCommand(docker, arguments: ["image", "rm", "-f"] + imageIds)
            freed += selected.filter { $0.kind == .image }.reduce(0) { $0 + $1.size }
        }

        // Remove volumes
        let volumeNames = selected.filter { $0.kind == .volume }.map(\.id)
        if !volumeNames.isEmpty {
            _ = runCommand(docker, arguments: ["volume", "rm"] + volumeNames)
        }

        // Build cache
        if selected.contains(where: { $0.kind == .buildCache }) {
            if let out = runCommand(docker, arguments: ["builder", "prune", "-f"]) {
                freed += parseReclaimedOutput(out)
            }
        }

        return freed
    }

    private func parseReclaimedOutput(_ output: String) -> Int64 {
        let pattern = #"Total reclaimed space: ([\d.]+)\s*(B|kB|MB|GB|TB)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let valRange = Range(match.range(at: 1), in: output),
              let unitRange = Range(match.range(at: 2), in: output)
        else { return 0 }
        let value = Double(output[valRange]) ?? 0
        let unit  = output[unitRange].lowercased()
        let mults: [String: Double] = ["b": 1, "kb": 1_000, "mb": 1_000_000, "gb": 1_000_000_000, "tb": 1_000_000_000_000]
        return Int64(value * (mults[unit] ?? 1))
    }
}
