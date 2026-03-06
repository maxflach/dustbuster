import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
final class SpaceLensViewModel {

    enum ViewMode: String, CaseIterable {
        case bubbles = "Bubbles"
        case treemap = "Treemap"
        case browser = "File Browser"

        var icon: String {
            switch self {
            case .bubbles: return "circles.hexagongrid"
            case .treemap: return "rectangle.split.2x2"
            case .browser: return "list.bullet.indent"
            }
        }
    }

    enum Phase {
        case idle
        case scanning(progress: ScanProgress?)
        case done
        case error(String)
    }

    // MARK: - State

    var phase: Phase = .idle
    var rootNode: FileSystemNode?
    var navigationStack: [FileSystemNode] = []
    var viewMode: ViewMode = .bubbles
    var selectedNode: FileSystemNode?
    var liveNodes: [FileSystemNode] = []

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    var currentNode: FileSystemNode? {
        navigationStack.last ?? rootNode
    }

    var scanProgress: ScanProgress? {
        if case .scanning(let p) = phase { return p }
        return nil
    }

    var breadcrumbs: [FileSystemNode] {
        guard let root = rootNode else { return [] }
        return [root] + navigationStack
    }

    // MARK: - Actions

    @MainActor
    func scan(url: URL? = nil) async {
        let targetURL = url ?? FileManager.default.homeDirectoryForCurrentUser
        phase = .scanning(progress: nil)
        navigationStack = []
        selectedNode = nil
        rootNode = nil
        liveNodes = []

        do {
            let node = try await DiskScannerService.shared.scan(
                url: targetURL,
                progress: { [weak self] prog in
                    Task { @MainActor [weak self] in
                        self?.phase = .scanning(progress: prog)
                    }
                },
                onFolderScanned: { [weak self] folder in
                    Task { @MainActor [weak self] in
                        self?.liveNodes.append(folder)
                    }
                }
            )
            rootNode = node
            phase = .done
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    @MainActor
    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Choose a folder to analyze:"

        if panel.runModal() == .OK, let url = panel.url {
            Task { await scan(url: url) }
        }
    }

    @MainActor
    func drillDown(into node: FileSystemNode) {
        guard node.isDirectory else { return }
        navigationStack.append(node)
        selectedNode = nil
    }

    @MainActor
    func navigateToBreadcrumb(_ node: FileSystemNode) {
        if node.id == rootNode?.id {
            navigationStack = []
        } else if let idx = navigationStack.firstIndex(where: { $0.id == node.id }) {
            navigationStack = Array(navigationStack.prefix(through: idx))
        }
        selectedNode = nil
    }

    @MainActor
    func goBack() {
        guard !navigationStack.isEmpty else { return }
        navigationStack.removeLast()
        selectedNode = nil
    }

    @MainActor
    func removeFiles(_ nodes: [FileSystemNode]) {
        let urls = nodes.map(\.url)
        let rootURL = rootNode?.url
        NSWorkspace.shared.recycle(urls) { _, _ in
            guard let rootURL else { return }
            Task { @MainActor [weak self] in
                await self?.scan(url: rootURL)
            }
        }
    }

    @MainActor
    func revealInFinder(_ node: FileSystemNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    @MainActor
    func moveToTrash(_ node: FileSystemNode) {
        let rootURL = rootNode?.url
        NSWorkspace.shared.recycle([node.url]) { _, _ in
            guard let rootURL else { return }
            Task { @MainActor [weak self] in
                await self?.scan(url: rootURL)
            }
        }
    }
}
