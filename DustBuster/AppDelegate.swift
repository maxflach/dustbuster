import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep app running even when all windows are closed (menu bar app)
        // The app stays alive via the MenuBarExtra scene.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false so closing the main window doesn't quit the app.
        // The app continues to live in the menu bar.
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}
