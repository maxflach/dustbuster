import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Environment(CleanupViewModel.self) private var cleanupVM

    var body: some View {
        List {
            ForEach(SidebarItem.allCases) { item in
                Button {
                    selection = item
                } label: {
                    Label(item.rawValue, systemImage: item.icon)
                        .badge(badgeText(for: item))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selection == item
                        ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.18))
                        : nil
                )
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .navigationTitle("DustBuster")
    }

    private func badgeText(for item: SidebarItem) -> String? {
        guard item == .smartCleanup, cleanupVM.totalSelectedSize > 0 else { return nil }
        return cleanupVM.formattedSelectedSize
    }
}
