import SwiftUI
import AppKit

/// A SwiftUI wrapper around NSTextField that properly manages focus
struct NativeTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onCommit: () -> Void = {}
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeTextField
        
        init(_ parent: NativeTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onEditingChanged(true)
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onEditingChanged(false)
            parent.onCommit()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = CustomTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.isEditable = true
        textField.isSelectable = true
        textField.drawsBackground = true
        textField.backgroundColor = NSColor.textBackgroundColor
        textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        
        // Setup text change notification
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
}

/// Custom TextField subclass to handle focus and first responder status
class CustomTextField: NSTextField {
    // Override first responder behavior to ensure we get focus
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // Force window to make this the first responder
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let window = self.window {
            window.makeFirstResponder(self)
        }
    }
    
    // Ensure activation on click
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // Tell the app that we're now active
            NSApp.activate(ignoringOtherApps: true)
        }
        return result
    }
    
    // Handle key events properly
    override func keyDown(with event: NSEvent) {
        // Make sure we're focused and forward the event
        if let window = self.window, window.firstResponder != self {
            window.makeFirstResponder(self)
        }
        super.keyDown(with: event)
    }
}
