import SwiftUI

struct MenuBarStatusView: View {
    @Environment(CleanupViewModel.self) private var cleanupVM
    @State private var freeDiskSpace: Int64 = 0
    @State private var totalDiskSpace: Int64 = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("DustBuster")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Disk space gauge
            diskGauge
                .padding(16)

            Divider()

            // Actions
            VStack(spacing: 8) {
                Button {
                    Task { await cleanupVM.scan() }
                    // Also open the main window
                    openMainWindow()
                } label: {
                    Label("Quick Clean", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(Color(red: 1.0, green: 0.78, blue: 0.1))

                Button {
                    openMainWindow()
                } label: {
                    Label("Open App", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Divider()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit DustBuster", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Last cleaned
            if let date = cleanupVM.lastCleanedDate {
                Divider()
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("Last cleaned: \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 280)
        .onAppear { refreshDiskSpace() }
    }

    // MARK: - Disk gauge

    private var diskGauge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Free Disk Space")
                    .font(.subheadline.bold())
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: freeDiskSpace, countStyle: .file))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if totalDiskSpace > 0 {
                let usedFraction = Double(totalDiskSpace - freeDiskSpace) / Double(totalDiskSpace)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(gaugeColor(fraction: usedFraction))
                            .frame(width: geo.size.width * CGFloat(usedFraction), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(ByteCountFormatter.string(fromByteCount: totalDiskSpace - freeDiskSpace, countStyle: .file)) used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(ByteCountFormatter.string(fromByteCount: totalDiskSpace, countStyle: .file)) total")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func gaugeColor(fraction: Double) -> Color {
        if fraction > 0.9 { return .red }
        if fraction > 0.75 { return .orange }
        return .blue
    }

    // MARK: - Helpers

    private func refreshDiskSpace() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return }
        freeDiskSpace = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        totalDiskSpace = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.windows.first(where: { $0.title == "DustBuster" }) == nil {
            // Window was closed — open a new one
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
                break
            }
        } else {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
