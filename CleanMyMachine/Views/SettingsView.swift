import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchService = LaunchAtLoginService.shared
    @State private var launchError: String?
    @State private var showingPermissionsSheet = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(isOn: Binding(
                    get: { launchService.isEnabled },
                    set: { _ in
                        do {
                            try launchService.toggle()
                            launchError = nil
                        } catch {
                            launchError = error.localizedDescription
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                        Text(launchService.statusDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let err = launchError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Permissions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Disk Access")
                        .font(.headline)
                    Text("CleanMyMachine needs Full Disk Access to clean system caches outside your home folder. Without it, only ~/Library paths are accessible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Open Privacy Settings…") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }

                Link("View Source on GitHub", destination: URL(string: "https://github.com")!)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: 480)
        .padding()
    }
}
