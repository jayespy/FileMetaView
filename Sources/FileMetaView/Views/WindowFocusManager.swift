import SwiftUI
import AppKit

/// A helper class to manage window focus and app activation
class WindowFocusManager {
    static let shared = WindowFocusManager()
    
    private init() {
        // Monitor application activation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Monitor window activation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Force the application to activate and come to foreground
    func forceActivateApp() {
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure the window is key and front
        if let window = NSApp.keyWindow {
            window.makeKeyAndOrderFront(nil)
            
            // Ensure the window is in front
            window.level = .floating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.level = .normal
            }
        }
    }
    
    /// Fix focus issues with text fields
    func fixTextFieldFocus() {
        if let window = NSApp.keyWindow {
            // Process responder chain to find any text fields
            var responder: NSResponder? = window.firstResponder
            while responder != nil {
                if let textField = responder as? NSTextField {
                    // If we found a text field, make sure it has focus
                    window.makeFirstResponder(textField)
                    break
                }
                responder = responder?.nextResponder
            }
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        // Make sure we're properly activated
        DispatchQueue.main.async {
            self.fixTextFieldFocus()
        }
    }
    
    @objc private func windowDidBecomeKey(notification: Notification) {
        // Fix focus when window becomes key
        DispatchQueue.main.async {
            self.fixTextFieldFocus()
        }
    }
}

/// SwiftUI view modifier to ensure proper window focus
struct EnsureWindowFocusModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Force activation when view appears
                WindowFocusManager.shared.forceActivateApp()
            }
            .onTapGesture {
                // Force activation on tap
                WindowFocusManager.shared.forceActivateApp()
            }
    }
}

extension View {
    /// Apply window focus handling to ensure proper activation
    func ensureWindowFocus() -> some View {
        self.modifier(EnsureWindowFocusModifier())
    }
}
