import SwiftUI
import ServiceManagement

@main
struct DustBusterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var cleanupViewModel = CleanupViewModel()
    @State private var spaceLensViewModel = SpaceLensViewModel()

    var body: some Scene {
        WindowGroup("DustBuster") {
            ContentView()
                .environment(cleanupViewModel)
                .environment(spaceLensViewModel)
                .frame(minWidth: 920, minHeight: 600)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Scan Now") {
                    Task { await cleanupViewModel.scan() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra("DustBuster", systemImage: "sparkles") {
            MenuBarStatusView()
                .environment(cleanupViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
