import Foundation

/// A node in the file system tree, representing a file or directory.
/// Used by Space Lens for treemap and browser views.
final class FileSystemNode: Identifiable {
    let id = UUID()
    let url: URL
    var size: Int64
    var children: [FileSystemNode]?
    var isDirectory: Bool

    var name: String { url.lastPathComponent }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var percentOfParent: Double = 0

    init(url: URL, size: Int64 = 0, isDirectory: Bool = false, children: [FileSystemNode]? = nil) {
        self.url = url
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
    }

    /// Recursively computes percentOfParent for all children.
    func computePercents() {
        guard let children, size > 0 else { return }
        for child in children {
            child.percentOfParent = size > 0 ? Double(child.size) / Double(size) : 0
            child.computePercents()
        }
    }

    /// Returns flattened sorted children, largest first.
    var sortedChildren: [FileSystemNode] {
        (children ?? []).sorted { $0.size > $1.size }
    }

    /// File type category for color-coding.
    var fileCategory: FileCategory {
        guard !isDirectory else { return .folder }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg":
            return .image
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv":
            return .video
        case "mp3", "aac", "flac", "wav", "m4a", "ogg":
            return .audio
        case "pdf", "doc", "docx", "pages", "txt", "rtf", "md":
            return .document
        case "app", "dmg", "pkg", "ipa":
            return .app
        case "zip", "tar", "gz", "bz2", "7z", "rar":
            return .archive
        case "swift", "py", "js", "ts", "go", "rs", "java", "c", "cpp", "h":
            return .code
        default:
            return .other
        }
    }
}

enum FileCategory: String, CaseIterable {
    case folder, image, video, audio, document, app, archive, code, other

    var colorHex: String {
        switch self {
        case .folder:   return "#5B9BD5"
        case .image:    return "#70C05A"
        case .video:    return "#E06B5B"
        case .audio:    return "#9B59B6"
        case .document: return "#F39C12"
        case .app:      return "#1ABC9C"
        case .archive:  return "#95A5A6"
        case .code:     return "#3498DB"
        case .other:    return "#7F8C8D"
        }
    }
}
