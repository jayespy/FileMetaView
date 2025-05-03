import SwiftUI
import AppKit

/// A completely different approach to text input - using a visual representation with global keyboard monitoring
struct CustomSearchField: View {
    @Binding var text: String
    var placeholder: String
    @Binding var isActive: Bool
    
    // State for keyboard monitor
    @State private var keyboardMonitor: KeyboardMonitor? = nil
    
    var body: some View {
        // This is just a visual representation of a text field
        HStack {
            Text(text.isEmpty ? placeholder : text)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).strokeBorder(isActive ? Color.accentColor : Color.gray, lineWidth: isActive ? 2 : 1))
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))
                .onTapGesture {
                    isActive = true
                    startMonitoring()
                    NSSound.beep() // Provide audio feedback that the field is active
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    isActive = true
                    startMonitoring()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onAppear {
            // Create the keyboard monitor
            keyboardMonitor = KeyboardMonitor(
                textChanged: { newText in
                    self.text = newText
                },
                initialText: text,
                isActive: $isActive
            )
        }
        .onDisappear {
            // Clean up the monitor when view disappears
            keyboardMonitor?.stopMonitoring()
            keyboardMonitor = nil
        }
        // Handle active state changes
        .onChange(of: isActive) { newValue in
            if newValue {
                startMonitoring()
            } else {
                keyboardMonitor?.stopMonitoring()
            }
        }
    }
    
    private func startMonitoring() {
        keyboardMonitor?.startMonitoring(withCurrentText: text)
    }
}

/// Keyboard monitor class that directly captures keyboard events globally
class KeyboardMonitor {
    // Callback when text changes
    private var textChanged: (String) -> Void
    
    // Currently monitored text
    private var currentText: String = ""
    
    // Active status
    private var isActive: Binding<Bool>
    
    // Global event monitor
    private var localEventMonitor: Any?
    
    init(textChanged: @escaping (String) -> Void, initialText: String, isActive: Binding<Bool>) {
        self.textChanged = textChanged
        self.currentText = initialText
        self.isActive = isActive
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Start monitoring keyboard events
    func startMonitoring(withCurrentText: String) {
        // Update text
        self.currentText = withCurrentText
        
        // Stop any existing monitor
        stopMonitoring()
        
        // Create a local event monitor for key down events
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self, self.isActive.wrappedValue else {
                return event
            }
            
            // Handle the key event
            if self.handleKeyEvent(event) {
                // If we handled it, return nil to consume the event
                return nil
            }
            
            // Otherwise, pass the event along
            return event
        }
        
        // Activate the application to ensure focus
        NSApp.activate(ignoringOtherApps: true)
        
        // Make sure we're active
        isActive.wrappedValue = true
        
        // Print status (for debugging)
        print("Keyboard monitoring started with text: \(withCurrentText)")
    }
    
    /// Stop monitoring keyboard events
    func stopMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
            print("Keyboard monitoring stopped")
        }
    }
    
    /// Handle a specific key event
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check if we're active
        guard isActive.wrappedValue else {
            return false
        }
        
        // Get the characters
        let chars = event.characters ?? ""
        
        // Check for special keys
        switch event.keyCode {
        case 36, 76: // Return, Enter
            // Deactivate on return/enter
            isActive.wrappedValue = false
            return true
            
        case 53: // Escape
            // Clear text or deactivate on escape
            if !currentText.isEmpty {
                currentText = ""
                textChanged(currentText)
            } else {
                isActive.wrappedValue = false
            }
            return true
            
        case 51: // Delete/Backspace
            // Handle backspace
            if !currentText.isEmpty {
                currentText.removeLast()
                textChanged(currentText)
            }
            return true
            
        default:
            // Handle regular character input
            if !chars.isEmpty && !event.modifierFlags.contains(.command) {
                currentText += chars
                textChanged(currentText)
                return true
            }
            
            // We didn't handle this key
            return false
        }
    }
}
