import Foundation
import SwiftUI
import AppKit

/// Utility class for handling application-level commands
class AppCommands {
    /// Shows the About panel with application information
    static func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.applicationName: "FileMetaView",
            NSApplication.AboutPanelOptionKey.applicationVersion: AppConfiguration.version,
            NSApplication.AboutPanelOptionKey.version: "",
            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                string: "A simple macOS utility for viewing file metadata.\nCreated as a learning project for SwiftUI."
            )
        ])
    }
    
    /// Copies text to the clipboard
    /// - Parameter text: The text to copy
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Opens a URL in the default browser
    /// - Parameter url: The URL to open
    static func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    /// Shows a simple alert
    /// - Parameters:
    ///   - title: The alert title
    ///   - message: The alert message
    static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Quits the application
    static func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}