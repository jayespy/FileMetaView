import SwiftUI
import AppKit

/// A NSViewRepresentable wrapper around NSTextField to ensure better text input handling
struct CocoaTextField: NSViewRepresentable {
    /// Placeholder text
    var placeholder: String
    
    /// Binding to the text value
    @Binding var text: String
    
    /// Binding to focus state
    @Binding var isFocused: Bool
    
    /// Create the underlying NSTextField
    func makeNSView(context: Context) -> CustomNSTextField {
        let textField = CustomNSTextField(frame: .zero)
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.isEditable = true
        textField.isSelectable = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textField.focusRingType = .exterior
        
        // Enable key input event handling
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textFieldAction(_:))
        
        context.coordinator.textField = textField
        
        return textField
    }
    
    /// Update the NSTextField when SwiftUI state changes
    func updateNSView(_ nsView: CustomNSTextField, context: Context) {
        // Update the text value if changed externally
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // Handle focus changes
        if isFocused {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder != nsView {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        } else {
            if nsView.window?.firstResponder == nsView {
                nsView.window?.makeFirstResponder(nil)
            }
        }
    }
    
    /// Create the coordinator to handle NSTextField delegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }
    
    /// Coordinator class to handle NSTextField delegate methods
    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>
        var textField: CustomNSTextField?
        
        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }
        
        @objc func textFieldAction(_ sender: NSTextField) {
            // Update the text when the field action is triggered
            text.wrappedValue = sender.stringValue
        }
        
        // Handle text changes
        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }
        
        // Handle focus
        func controlTextDidBeginEditing(_ notification: Notification) {
            isFocused.wrappedValue = true
        }
        
        func controlTextDidEndEditing(_ notification: Notification) {
            isFocused.wrappedValue = false
        }
    }
}

/// Custom NSTextField subclass for improved input handling
class CustomNSTextField: NSTextField {
    // Override to ensure keyboard events are properly processed
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for common key commands and don't handle them here
        if event.type == .keyDown {
            if event.modifierFlags.contains(.command) {
                // Let command key combinations pass through to responder chain
                return false
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    // Override to ensure text input is properly processed
    override func keyDown(with event: NSEvent) {
        // Process key events normally
        super.keyDown(with: event)
    }
    
    // Improved text input handling
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        // If we successfully became first responder, select all text for convenience
        if result {
            self.selectText(nil)
        }
        return result
    }
}
