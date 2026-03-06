import SwiftUI
import ServiceManagement

@main
struct CleanMyMachineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var cleanupViewModel = CleanupViewModel()
    @State private var spaceLensViewModel = SpaceLensViewModel()

    var body: some Scene {
        WindowGroup("CleanMyMachine") {
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

        MenuBarExtra("CleanMyMachine", systemImage: "sparkles") {
            MenuBarStatusView()
                .environment(cleanupViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
