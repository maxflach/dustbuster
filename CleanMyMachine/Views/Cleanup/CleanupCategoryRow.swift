import SwiftUI

struct CleanupCategoryRow: View {
    let result: CleanupCategoryResult
    let onToggle: () -> Void
    var onToggleDockerResource: ((String) -> Void)? = nil
    var onSelectDockerOrphansOnly: (() -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 14) {
                // Toggle
                Toggle("", isOn: .init(get: { result.isSelected }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .toggleStyle(.checkbox)

                // Icon
                Image(systemName: result.category.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.rawValue)
                        .font(.headline)
                    Text(result.category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Size + count
                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.formattedSize)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(result.totalSize > 0 ? .primary : .secondary)
                    Text("\(result.itemCount) item\(result.itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Expand arrow (only when items or docker resources exist)
                if !result.items.isEmpty || !result.dockerResources.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Expanded content
            if isExpanded {
                Divider().padding(.horizontal, 16)

                if result.category.isDocker {
                    // Docker: rich grouped resource list
                    DockerDetailView(
                        resources: result.dockerResources,
                        onToggle: { onToggleDockerResource?($0) },
                        onSelectOrphansOnly: { onSelectDockerOrphansOnly?() }
                    )
                } else if !result.items.isEmpty {
                    // Regular categories: simple file list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(result.items.prefix(50)) { item in
                                HStack {
                                    Image(systemName: "doc")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    Text(item.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(item.formattedSize)
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                                Divider().padding(.leading, 44)
                            }
                            if result.items.count > 50 {
                                Text("…and \(result.items.count - 50) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        )
        .opacity(result.isSelected ? 1 : 0.5)
    }

    private var iconColor: Color {
        switch result.category {
        case .systemCaches:   return .blue
        case .appLogs:        return .orange
        case .trash:          return .red
        case .browserCaches:  return .purple
        case .docker:         return .cyan
        }
    }
}
