import Foundation
import ServiceManagement

/// Wraps SMAppService to manage Launch at Login registration.
@Observable
final class LaunchAtLoginService {

    static let shared = LaunchAtLoginService()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:           return "Enabled"
        case .requiresApproval:  return "Requires Approval"
        case .notRegistered:     return "Disabled"
        case .notFound:          return "Not Found"
        @unknown default:        return "Unknown"
        }
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}
