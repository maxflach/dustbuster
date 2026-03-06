import SwiftUI

struct CleanupView: View {
    @Environment(CleanupViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(.regularMaterial)

            Divider()

            // Content
            Group {
                switch vm.phase {
                case .idle:
                    idleView
                case .scanning:
                    scanningView
                case .scanned:
                    resultsView
                case .cleaning:
                    cleaningView
                case .done(let bytes, let errors):
                    doneView(bytesFreed: bytes, errors: errors)
                case .error(let msg):
                    errorView(msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Smart Cleanup")
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Cleanup")
                    .font(.title2.bold())
                Text("Remove caches, logs, trash, and browser leftovers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch vm.phase {
        case .idle, .done, .error:
            Button {
                Task { await vm.scan() }
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
                    .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .scanned:
            HStack(spacing: 10) {
                Button {
                    Task { await vm.scan() }
                } label: {
                    Label("Re-scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    Task { await vm.clean() }
                } label: {
                    Label("Clean \(vm.formattedSelectedSize)", systemImage: "trash")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(vm.totalSelectedSize == 0)
            }

        case .scanning, .cleaning:
            ProgressView()
                .controlSize(.regular)
                .padding(.trailing, 8)
        }
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 64))
                .foregroundStyle(.yellow.opacity(0.8))
            Text("Ready to scan")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Click Scan to find files you can safely remove.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning \(vm.scanningCategoryName)…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.results) { result in
                    CleanupCategoryRow(
                        result: result,
                        onToggle: { vm.toggleCategory(result.category) },
                        onToggleDockerResource: { vm.toggleDockerResource(id: $0) },
                        onSelectDockerOrphansOnly: { vm.selectDockerOrphansOnly() }
                    )
                }
            }
            .padding(20)
        }
    }

    private var cleaningView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            if case .cleaning(let file) = vm.phase {
                Text("Removing \(file)…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func doneView(bytesFreed: Int64, errors: [CleanupError]) -> some View {
        VStack(spacing: 20) {
            Image(systemName: errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(errors.isEmpty ? .green : .orange)

            Text(errors.isEmpty ? "All done!" : "Cleaned with warnings")
                .font(.title2.bold())

            Text("\(ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)) freed")
                .font(.title3)
                .foregroundStyle(.secondary)

            if !errors.isEmpty {
                DisclosureGroup("Show \(errors.count) warning(s)") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(errors.indices, id: \.self) { i in
                            Text(errors[i].localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
