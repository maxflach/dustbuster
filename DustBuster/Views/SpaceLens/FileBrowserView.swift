import SwiftUI
import AppKit

struct FileBrowserView: View {
    let rootNode: FileSystemNode
    let onDrillDown: (FileSystemNode) -> Void
    let onRevealInFinder: (FileSystemNode) -> Void
    let onMoveToTrash: (FileSystemNode) -> Void

    @State private var selectedNodeID: UUID?

    var body: some View {
        Table(rootNode.sortedChildren, selection: $selectedNodeID) {
            TableColumn("Name") { node in
                nameCell(for: node)
            }
            .width(min: 200, ideal: 320)

            TableColumn("Size") { node in
                Text(node.formattedSize)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(node.size == 0 ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(90)

            TableColumn("%") { node in
                HStack(spacing: 6) {
                    let pct = node.percentOfParent
                    ProgressView(value: pct)
                        .progressViewStyle(.linear)
                        .tint(barColor(for: pct))
                    Text(String(format: "%.1f%%", pct * 100))
                        .font(.caption.monospacedDigit())
                        .frame(width: 42, alignment: .trailing)
                }
            }
            .width(120)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first,
               let node = rootNode.sortedChildren.first(where: { $0.id == id }) {
                Button("Reveal in Finder") { onRevealInFinder(node) }
                Button("Move to Trash", role: .destructive) { onMoveToTrash(node) }
                Divider()
                if node.isDirectory {
                    Button("Drill Into Folder") { onDrillDown(node) }
                }
            }
        } primaryAction: { ids in
            if let id = ids.first,
               let node = rootNode.sortedChildren.first(where: { $0.id == id }),
               node.isDirectory {
                onDrillDown(node)
            }
        }
    }

    private func nameCell(for node: FileSystemNode) -> some View {
        HStack(spacing: 8) {
            Image(systemName: node.isDirectory ? "folder.fill" : iconName(for: node))
                .foregroundStyle(node.isDirectory ? .blue : .secondary)
                .frame(width: 18)

            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)

            if node.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func iconName(for node: FileSystemNode) -> String {
        switch node.fileCategory {
        case .image:    return "photo"
        case .video:    return "film"
        case .audio:    return "music.note"
        case .document: return "doc.text"
        case .app:      return "app"
        case .archive:  return "archivebox"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        default:        return "doc"
        }
    }

    private func barColor(for pct: Double) -> Color {
        if pct > 0.5 { return .red }
        if pct > 0.25 { return .orange }
        return .blue
    }
}
