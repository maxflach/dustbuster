import Foundation

/// A single file or folder that can be cleaned up.
struct CleanupItem: Identifiable {
    let id = UUID()
    let url: URL
    var size: Int64
    var isSelected: Bool = true

    var name: String { url.lastPathComponent }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Aggregated state for one cleanup category after scanning.
struct CleanupCategoryResult: Identifiable {
    let id: CleanupCategory
    let category: CleanupCategory
    var items: [CleanupItem]
    var isSelected: Bool = true
    var dockerResources: [DockerResource] = []

    var totalSize: Int64 {
        category.isDocker
            ? dockerResources.reduce(0) { $0 + $1.size }
            : items.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        category.isDocker
            ? dockerResources.filter(\.isSelected).reduce(0) { $0 + $1.size }
            : items.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var itemCount: Int {
        category.isDocker ? dockerResources.count : items.count
    }

    init(category: CleanupCategory, items: [CleanupItem] = [], dockerResources: [DockerResource] = []) {
        self.id = category
        self.category = category
        self.items = items
        self.dockerResources = dockerResources
    }
}
