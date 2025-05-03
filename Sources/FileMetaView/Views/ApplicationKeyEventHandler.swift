import SwiftUI
import AppKit

/// A global key event handler for the entire application
class ApplicationKeyEventHandler {
    static let shared = ApplicationKeyEventHandler()
    
    // Callback for when text should be handled
    var onTextChange: ((String) -> Void)?
    
    // Current search text
    private var currentText: String = ""
    
    // Event monitors
    private var localEventMonitor: Any?
    
    // Is search active
    private var isSearchActive = false
    
    private init() {
        setupMonitor()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Start monitoring keyboard events
    func activateSearch(withCurrentText: String) {
        self.currentText = withCurrentText
        self.isSearchActive = true
        
        // Force the app to activate
        NSApp.activate(ignoringOtherApps: true)
        
        // Print status message
        print("Search activated with text: \(withCurrentText)")
        
        // Beep to indicate search is active
        NSSound.beep()
    }
    
    /// Stop capturing text for search
    func deactivateSearch() {
        isSearchActive = false
        print("Search deactivated")
    }
    
    /// Setup the event monitor
    private func setupMonitor() {
        // Stop existing monitor if any
        stopMonitoring()
        
        // Create a local event monitor for key down events
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self else { return event }
            
            // Only handle events when search is active
            if self.isSearchActive {
                // Print event for debugging
                print("Key event: \(event.keyCode), chars: \(event.characters ?? "")")
                
                // Handle the key event
                if self.handleKeyEvent(event) {
                    // If we handled it, return nil to consume the event
                    return nil
                }
            }
            
            // Otherwise, pass the event along
            return event
        }
    }
    
    /// Stop monitoring keyboard events
    private func stopMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    /// Handle a specific key event
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Get the characters
        let chars = event.characters ?? ""
        
        // Check for special keys
        switch event.keyCode {
        case 36, 76: // Return, Enter
            // Deactivate on return/enter
            deactivateSearch()
            return true
            
        case 53: // Escape
            // Clear text or deactivate on escape
            if !currentText.isEmpty {
                currentText = ""
                onTextChange?(currentText)
            } else {
                deactivateSearch()
            }
            return true
            
        case 51: // Delete/Backspace
            // Handle backspace
            if !currentText.isEmpty {
                currentText.removeLast()
                onTextChange?(currentText)
            }
            return true
            
        default:
            // Handle regular character input
            if !chars.isEmpty && !event.modifierFlags.contains(.command) {
                currentText += chars
                onTextChange?(currentText)
                return true
            }
            
            // We didn't handle this key
            return false
        }
    }
}

/// View modifier to add application-wide key event handling
struct ApplicationKeyEventHandlerModifier: ViewModifier {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Set up the callback
                ApplicationKeyEventHandler.shared.onTextChange = { newText in
                    DispatchQueue.main.async {
                        self.searchText = newText
                    }
                }
            }
            .onChange(of: isSearchActive) { newValue in
                if newValue {
                    ApplicationKeyEventHandler.shared.activateSearch(withCurrentText: searchText)
                } else {
                    ApplicationKeyEventHandler.shared.deactivateSearch()
                }
            }
    }
}

extension View {
    /// Add application-wide key event handling for search
    func withGlobalSearchHandler(searchText: Binding<String>, isActive: Binding<Bool>) -> some View {
        self.modifier(ApplicationKeyEventHandlerModifier(searchText: searchText, isSearchActive: isActive))
    }
}
