import SwiftUI

struct FileRemoveList: View {
    let nodes: [FileSystemNode]
    let onDrillDown: (FileSystemNode) -> Void
    let onRevealInFinder: (FileSystemNode) -> Void
    let onRemove: ([FileSystemNode]) -> Void

    @State private var selected = Set<UUID>()
    @State private var pendingRemove: [FileSystemNode] = []
    @State private var showConfirm = false

    private var selectedNodes: [FileSystemNode] {
        nodes.filter { selected.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedNodes.reduce(0) { $0 + $1.size }
    }

    private static let sensitivePaths: [String] = [
        "/Library", "/System", "/usr", "/bin", "/sbin", "/etc",
        "/private", "/Applications", "Frameworks", "PrivateFrameworks",
        "LaunchAgents", "LaunchDaemons", "Extensions",
        "Preferences", "Application Support"
    ]

    private func isSensitive(_ items: [FileSystemNode]) -> Bool {
        items.contains { node in
            Self.sensitivePaths.contains { node.url.path.contains($0) }
        }
    }

    private func requestRemove(_ items: [FileSystemNode]) {
        guard !items.isEmpty else { return }
        pendingRemove = items
        showConfirm = true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 12) {
                Text(nodes.isEmpty ? "No files here" : "\(nodes.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if !selected.isEmpty {
                    Text("\(selected.count) selected · \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button(role: .destructive) {
                        requestRemove(selectedNodes)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            if nodes.isEmpty {
                Text("This folder is empty.")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(nodes, selection: $selected) {
                    TableColumn("") { node in
                        Toggle("", isOn: Binding(
                            get: { selected.contains(node.id) },
                            set: { checked in
                                if checked { selected.insert(node.id) }
                                else { selected.remove(node.id) }
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                    }
                    .width(20)

                    TableColumn("Name") { node in
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
                    .width(min: 180, ideal: 300)

                    TableColumn("Size") { node in
                        Text(node.formattedSize)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(node.size == 0 ? .tertiary : .primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(90)

                    TableColumn("%") { node in
                        HStack(spacing: 6) {
                            ProgressView(value: node.percentOfParent)
                                .progressViewStyle(.linear)
                                .tint(barColor(for: node.percentOfParent))
                            Text(String(format: "%.1f%%", node.percentOfParent * 100))
                                .font(.caption.monospacedDigit())
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                    .width(120)
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let id = ids.first, let node = nodes.first(where: { $0.id == id }) {
                        Button("Reveal in Finder") { onRevealInFinder(node) }
                        if node.isDirectory {
                            Button("Open Folder") { onDrillDown(node) }
                        }
                        Divider()
                        Button("Move to Trash", role: .destructive) {
                            requestRemove([node])
                        }
                    }
                } primaryAction: { ids in
                    if let id = ids.first,
                       let node = nodes.first(where: { $0.id == id }),
                       node.isDirectory {
                        onDrillDown(node)
                    }
                }
            }
        }
        .confirmationDialog(
            isSensitive(pendingRemove)
                ? "⚠️ System or Application Files"
                : "Move to Trash?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                onRemove(pendingRemove)
                selected = []
                pendingRemove = []
            }
            Button("Cancel", role: .cancel) { pendingRemove = [] }
        } message: {
            let size = ByteCountFormatter.string(
                fromByteCount: pendingRemove.reduce(0) { $0 + $1.size },
                countStyle: .file
            )
            if isSensitive(pendingRemove) {
                Text("These files are inside a system or application folder. Removing them may corrupt software or break your system.\n\nSize: \(size)")
            } else {
                Text("Move \(pendingRemove.count == 1 ? "this item" : "\(pendingRemove.count) items") (\(size)) to the Trash? You can restore them from the Trash if needed.")
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
