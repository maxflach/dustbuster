import SwiftUI

struct SpaceLensView: View {
    @Environment(SpaceLensViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            // Toolbar
            toolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)

            Divider()

            // Main content
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Space Lens")
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 28))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Space Lens")
                    .font(.title3.bold())
                if let root = vm.rootNode {
                    Text(root.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                } else {
                    Text("Analyze disk usage visually")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // View mode picker
            if vm.rootNode != nil {
                Picker("View", selection: Binding(get: { vm.viewMode }, set: { vm.viewMode = $0 })) {
                    ForEach(SpaceLensViewModel.ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }

            // Back button
            if !vm.navigationStack.isEmpty {
                Button {
                    vm.goBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            }

            // Scan buttons
            Button {
                Task { await vm.scan() }
            } label: {
                Label("Home", systemImage: "house")
            }
            .buttonStyle(.bordered)
            .disabled(vm.isScanning)

            Button {
                vm.pickFolder()
            } label: {
                Label("Pick Folder…", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isScanning)
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(vm.breadcrumbs, id: \.id) { crumb in
                    Button {
                        vm.navigateToBreadcrumb(crumb)
                    } label: {
                        Text(crumb.name.isEmpty ? "Home" : crumb.name)
                            .font(.callout)
                            .foregroundStyle(crumb.id == vm.currentNode?.id ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)

                    if crumb.id != vm.breadcrumbs.last?.id {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch vm.phase {
        case .idle:
            idleView

        case .scanning(let progress):
            ZStack(alignment: .bottom) {
                if !vm.navigationStack.isEmpty, let current = vm.currentNode {
                    // User drilled into a completed folder — show its contents
                    bubblesView(current: current)
                } else if vm.liveNodes.isEmpty {
                    scanningIdleView
                } else {
                    BubbleChartView(nodes: vm.liveNodes, onTap: { vm.drillDown(into: $0) })
                }
                scanningStatusBar(progress: progress)
            }

        case .done:
            if let current = vm.currentNode {
                switch vm.viewMode {
                case .bubbles:
                    bubblesView(current: current)

                case .treemap:
                    TreemapView(
                        nodes: current.sortedChildren,
                        onDrillDown: { vm.drillDown(into: $0) }
                    )
                    .padding(12)

                case .browser:
                    FileBrowserView(
                        rootNode: current,
                        onDrillDown: { vm.drillDown(into: $0) },
                        onRevealInFinder: { vm.revealInFinder($0) },
                        onMoveToTrash: { vm.moveToTrash($0) }
                    )
                }
            }

        case .error(let msg):
            errorView(msg)
        }
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundStyle(.blue.opacity(0.7))
            Text("Select a folder to analyze")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var scanningIdleView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Scanning…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func scanningStatusBar(progress: ScanProgress?) -> some View {
        VStack(spacing: 6) {
            if let p = progress {
                ProgressView(value: p.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                HStack {
                    Text("\(p.scannedFiles.formatted()) files · \(ByteCountFormatter.string(fromByteCount: p.totalSize, countStyle: .file))")
                        .monospacedDigit()
                    Spacer()
                    Text(p.currentPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Bubbles done view

    @ViewBuilder
    private func bubblesView(current: FileSystemNode) -> some View {
        let folders = current.sortedChildren.filter(\.isDirectory)
        // Folders first (sorted by size), then files
        let allSorted = folders + current.sortedChildren.filter { !$0.isDirectory }

        if folders.isEmpty {
            VStack(spacing: 0) {
                breadcrumbBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.background.secondary)
                Divider()
                fileRemoveList(nodes: allSorted)
            }
        } else {
            VSplitView {
                BubbleChartView(nodes: folders, onTap: { vm.drillDown(into: $0) })
                    .frame(minHeight: 200)
                VStack(spacing: 0) {
                    breadcrumbBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(.background.secondary)
                    Divider()
                    fileRemoveList(nodes: allSorted)
                }
                .frame(minHeight: 160)
            }
        }
    }

    private func fileRemoveList(nodes: [FileSystemNode]) -> some View {
        FileRemoveList(
            nodes: nodes,
            onDrillDown: { vm.drillDown(into: $0) },
            onRevealInFinder: { vm.revealInFinder($0) },
            onRemove: { vm.removeFiles($0) }
        )
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Scan failed")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
                .multilineTextAlignment(.center)
        }
    }
}
