import SwiftUI
import AppKit

/// Forces the application window to remain active and intercepts window events
class ForceActiveWindow {
    static let shared = ForceActiveWindow()
    
    // Window monitor to override behavior
    private var windowMonitor: NSWindowController?
    
    // Original window level
    private var originalLevel: NSWindow.Level?
    
    private init() {
        // Register for app notification when it's ready
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidFinishLaunching),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }
    
    deinit {
        // Remove observers
        NotificationCenter.default.removeObserver(self)
        
        // Restore window behavior
        restoreWindowBehavior()
    }
    
    /// Apply the force active behavior to the key window
    func forceWindowActive() {
        DispatchQueue.main.async {
            // Get current key window
            guard let window = NSApp.keyWindow else { return }
            
            // Skip if we're already monitoring this window
            if self.windowMonitor?.window == window {
                self.forceActivation()
                return
            }
            
            // Store original level
            self.originalLevel = window.level
            
            // Create window controller to monitor
            let controller = NSWindowController(window: window)
            self.windowMonitor = controller
            
            // Force window to be key and active
            self.forceActivation()
            
            // Install window delegate if needed
            if !(window.delegate is ForcedActiveWindowDelegate) {
                let delegate = ForcedActiveWindowDelegate()
                // Store original delegate if needed
                if let originalDelegate = window.delegate {
                    delegate.originalDelegate = originalDelegate
                }
                window.delegate = delegate
            }
            
            // Start watching notifications
            self.setupWindowNotifications(for: window)
            
            print("ForceActiveWindow applied to window: \(window)")
        }
    }
    
    /// Restore original window behavior
    func restoreWindowBehavior() {
        guard let window = windowMonitor?.window else { return }
        
        // Restore original level
        if let level = originalLevel {
            window.level = level
        }
        
        // Remove delegate if it's our forced delegate
        if let delegate = window.delegate as? ForcedActiveWindowDelegate {
            window.delegate = delegate.originalDelegate
        }
        
        // Clear references
        windowMonitor = nil
        originalLevel = nil
        
        print("Restored original window behavior")
    }
    
    /// Force activation of the application and window
    func forceActivation() {
        guard let window = windowMonitor?.window else { return }
        
        // Make app active
        NSApp.activate(ignoringOtherApps: true)
        
        // Make window key and visible
        window.makeKeyAndOrderFront(nil)
        
        // Set window level higher to keep it visible
        window.level = .floating
        
        // Return to normal level after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.level = .normal
        }
        
        print("Force activation applied")
    }
    
    /// Setup notification observers for window events
    private func setupWindowNotifications(for window: NSWindow) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc private func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply force active when app launches
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.forceWindowActive()
        }
    }
    
    @objc private func windowDidResignKey(_ notification: Notification) {
        // Force window back to active state when it loses focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.forceActivation()
        }
    }
    
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        // Ensure window is properly configured when it becomes key
        guard let window = notification.object as? NSWindow else { return }
        
        // Update our reference if needed
        if windowMonitor?.window != window {
            windowMonitor = NSWindowController(window: window)
        }
    }
}

/// Custom window delegate to override window behavior
class ForcedActiveWindowDelegate: NSObject, NSWindowDelegate {
    // Store original delegate to forward methods
    var originalDelegate: NSWindowDelegate?
    
    // Override window behavior to keep it active
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Forward to original delegate
        if let result = originalDelegate?.windowShouldClose?(sender) {
            return result
        }
        return true
    }
    
    // Prevent window from resigning key status
    func windowDidResignKey(_ notification: Notification) {
        // Forward to original delegate
        originalDelegate?.windowDidResignKey?(notification)
        
        // Re-activate the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ForceActiveWindow.shared.forceActivation()
        }
    }
    
    // Window will enter full screen
    func windowWillEnterFullScreen(_ notification: Notification) {
        // Forward to original delegate
        originalDelegate?.windowWillEnterFullScreen?(notification)
    }
    
    // Window will exit full screen
    func windowWillExitFullScreen(_ notification: Notification) {
        // Forward to original delegate
        originalDelegate?.windowWillExitFullScreen?(notification)
    }
}

/// SwiftUI view modifier to apply force active window behavior
struct ForceActiveWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ForceActiveWindow.shared.forceWindowActive()
                }
            }
    }
}

extension View {
    /// Apply force active window behavior to this view
    func forceActiveWindow() -> some View {
        modifier(ForceActiveWindowModifier())
    }
}
