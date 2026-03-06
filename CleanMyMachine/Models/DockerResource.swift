import Foundation

enum DockerResourceKind: String, CaseIterable {
    case image      = "Images"
    case container  = "Containers"
    case volume     = "Volumes"
    case buildCache = "Build Cache"

    var icon: String {
        switch self {
        case .image:      return "photo.stack"
        case .container:  return "shippingbox"
        case .volume:     return "cylinder"
        case .buildCache: return "hammer"
        }
    }
}

struct DockerResource: Identifiable {
    let id: String
    let kind: DockerResourceKind
    let name: String
    let size: Int64
    let isOrphan: Bool   // dangling / stopped / unused
    let status: String   // human-readable status label
    var isSelected: Bool

    var formattedSize: String {
        size > 0 ? ByteCountFormatter.string(fromByteCount: size, countStyle: .file) : "—"
    }
}
