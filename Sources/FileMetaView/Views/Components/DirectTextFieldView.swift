import SwiftUI
import AppKit

/// A completely custom wrapper for NSTextField that directly handles focus and text input
public struct DirectTextFieldView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isActive: Bool = true
    
    public func makeNSView(context: Context) -> NSTextField {
        // Create the NSTextField
        let field = FocusAwareTextField()
        
        // Configure the text field
        field.isEditable = isActive
        field.isSelectable = true
        field.isEnabled = isActive
        field.isBordered = true
        field.drawsBackground = true
        field.backgroundColor = NSColor.textBackgroundColor
        field.placeholderString = placeholder
        field.stringValue = text
        field.bezelStyle = .roundedBezel
        field.target = context.coordinator
        field.action = #selector(Coordinator.textFieldAction(_:))
        field.delegate = context.coordinator
        
        // Store reference to the coordinator
        field.coordinator = context.coordinator
        
        return field
    }
    
    public func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if text has changed externally to avoid cursor jumping
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DirectTextFieldView
        
        init(_ parent: DirectTextFieldView) {
            self.parent = parent
            super.init()
            
            // Register for app activation notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidBecomeActive),
                name: NSApplication.didBecomeActiveNotification,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func applicationDidBecomeActive() {
            // Force the application to become active when this text field is used
            if let app = NSApplication.shared.keyWindow?.firstResponder as? NSTextField,
               app is FocusAwareTextField {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        
        @objc func textFieldAction(_ sender: NSTextField) {
            parent.text = sender.stringValue
        }
        
        // TextView delegate methods
        public func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                // Update the binding
                parent.text = textField.stringValue
            }
        }
        
        public func controlTextDidEndEditing(_ notification: Notification) {
            // Ensure we stay in first responder if needed
            if let textField = notification.object as? FocusAwareTextField {
                // Update the binding one last time
                parent.text = textField.stringValue
            }
        }
        
        public func controlTextDidBeginEditing(_ notification: Notification) {
            // Make sure app is active
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// Custom NSTextField subclass that properly manages focus
class FocusAwareTextField: NSTextField {
    // Store reference to the coordinator for callbacks
    weak var coordinator: DirectTextFieldView.Coordinator?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.focusRingType = .default
    }
    
    // Always accept first responder status
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // Force activation when becoming first responder
    override func becomeFirstResponder() -> Bool {
        // Tell app to activate
        NSApp.activate(ignoringOtherApps: true)
        
        // If we're in a window, make sure the window is key
        if let window = self.window, !window.isKeyWindow {
            window.makeKeyAndOrderFront(nil)
        }
        
        return super.becomeFirstResponder()
    }
    
    // Force field to become first responder on mouse down
    override func mouseDown(with event: NSEvent) {
        // Handle the mouseDown event
        super.mouseDown(with: event)
        
        // Make sure this field becomes first responder
        if let window = self.window {
            window.makeFirstResponder(self)
            
            // Force app activation
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // Better key event handling
    override func keyDown(with event: NSEvent) {
        // Ensure we're first responder
        if let window = self.window, window.firstResponder != self {
            window.makeFirstResponder(self)
        }
        super.keyDown(with: event)
    }
    
    // Improved text handling
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        
        // Ensure focus ring is visible
        self.needsDisplay = true
    }
    
    // Prevent focus loss when field is clicked
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        // Ensure we still have focus
        if let window = self.window, window.firstResponder != self {
            window.makeFirstResponder(self)
        }
    }
}
