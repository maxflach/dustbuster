import Foundation
import SwiftUI

@Observable
final class CleanupViewModel {

    // MARK: - State

    enum Phase {
        case idle
        case scanning(category: String)
        case scanned
        case cleaning(file: String)
        case done(bytesFreed: Int64, errors: [CleanupError])
        case error(String)
    }

    var phase: Phase = .idle
    var results: [CleanupCategoryResult] = []
    var lastCleanedDate: Date? = nil

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    var isCleaning: Bool {
        if case .cleaning = phase { return true }
        return false
    }

    var totalSelectedSize: Int64 {
        results
            .filter { $0.isSelected }
            .reduce(0) { $0 + $1.selectedSize }
    }

    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }

    // MARK: - Actions

    @MainActor
    func scan() async {
        phase = .scanning(category: "")
        results = []

        let categoryResults = await CleanupService.shared.scan(
            onProgress: { [weak self] category in
                Task { @MainActor [weak self] in
                    self?.phase = .scanning(category: category.rawValue)
                }
            }
        )

        results = categoryResults
        phase = .scanned
    }

    @MainActor
    func clean() async {
        guard case .scanned = phase else { return }

        phase = .cleaning(file: "")

        let (bytesFreed, errors) = await CleanupService.shared.clean(
            results: results,
            onProgress: { [weak self] url in
                Task { @MainActor [weak self] in
                    self?.phase = .cleaning(file: url.lastPathComponent)
                }
            }
        )

        lastCleanedDate = Date()
        phase = .done(bytesFreed: bytesFreed, errors: errors)

        // Re-scan automatically to update sizes after cleaning
        try? await Task.sleep(for: .seconds(1.5))
        await scan()
    }

    @MainActor
    func reset() {
        phase = .idle
        results = []
    }

    func toggleCategory(_ category: CleanupCategory) {
        guard let idx = results.firstIndex(where: { $0.category == category }) else { return }
        results[idx].isSelected.toggle()
    }

    func toggleDockerResource(id: String) {
        guard let catIdx = results.firstIndex(where: { $0.category == .docker }),
              let resIdx = results[catIdx].dockerResources.firstIndex(where: { $0.id == id })
        else { return }
        results[catIdx].dockerResources[resIdx].isSelected.toggle()
    }

    func selectDockerOrphansOnly() {
        guard let idx = results.firstIndex(where: { $0.category == .docker }) else { return }
        for i in results[idx].dockerResources.indices {
            results[idx].dockerResources[i].isSelected = results[idx].dockerResources[i].isOrphan
        }
    }

    var scanningCategoryName: String {
        if case .scanning(let name) = phase { return name }
        return ""
    }

    var doneFreedSize: String {
        if case .done(let bytes, _) = phase {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        return "0 KB"
    }

    var doneErrors: [CleanupError] {
        if case .done(_, let errors) = phase { return errors }
        return []
    }
}
