import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case smartCleanup = "Smart Cleanup"
    case spaceLens = "Space Lens"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smartCleanup: return "sparkles"
        case .spaceLens:    return "magnifyingglass.circle"
        case .settings:     return "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(CleanupViewModel.self) private var cleanupVM
    @Environment(SpaceLensViewModel.self) private var spaceLensVM

    @State private var selectedItem: SidebarItem? = .smartCleanup

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            switch selectedItem {
            case .smartCleanup, .none:
                CleanupView()
            case .spaceLens:
                SpaceLensView()
            case .settings:
                SettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
