import SwiftUI

struct DockerDetailView: View {
    let resources: [DockerResource]
    let onToggle: (String) -> Void
    let onSelectOrphansOnly: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Quick actions bar
            HStack {
                let orphanCount = resources.filter(\.isOrphan).count
                Text("\(resources.count) resource\(resources.count == 1 ? "" : "s") · \(orphanCount) orphan\(orphanCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Select Orphans Only") {
                    onSelectOrphansOnly()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.horizontal, 16)

            // Grouped sections
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(DockerResourceKind.allCases, id: \.self) { kind in
                        let items = resources.filter { $0.kind == kind }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { resource in
                                    resourceRow(resource)
                                    if resource.id != items.last?.id {
                                        Divider().padding(.leading, 44)
                                    }
                                }
                            } header: {
                                sectionHeader(kind: kind, items: items)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }

    private func sectionHeader(kind: DockerResourceKind, items: [DockerResource]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind.icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(kind.rawValue)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            let total = items.filter { $0.size > 0 }.reduce(0) { $0 + $1.size }
            if total > 0 {
                Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(.background.secondary)
    }

    private func resourceRow(_ resource: DockerResource) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { resource.isSelected },
                set: { _ in onToggle(resource.id) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(resource.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    statusBadge(resource)
                    if resource.kind != .container {
                        Text("ID: \(resource.id.prefix(8))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text(resource.formattedSize)
                .font(.callout.monospacedDigit())
                .foregroundStyle(resource.size > 0 ? .primary : .tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { onToggle(resource.id) }
    }

    @ViewBuilder
    private func statusBadge(_ resource: DockerResource) -> some View {
        let (label, color): (String, Color) = {
            switch resource.status {
            case "Dangling":   return ("Dangling", .orange)
            case "Stopped":    return ("Stopped", .red)
            case "Unused":     return ("Unused", .orange)
            case "Running":    return ("Running", .green)
            case "Reclaimable": return ("Reclaimable", .yellow)
            default:           return (resource.status, .secondary)
            }
        }()

        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}
