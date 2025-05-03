import SwiftUI
import AppKit

/// A custom search field that uses AppKit to ensure focus and activates the window
class PatchedSearchField: NSTextField {
    var onTextChange: ((String) -> Void)?
    
    // Override these behaviors to capture focus
    override var acceptsFirstResponder: Bool { return true }
    override var canBecomeKeyView: Bool { return true }
    
    // Initialize with a callback
    init(onTextChange: @escaping (String) -> Void) {
        self.onTextChange = onTextChange
        super.init(frame: .zero)
        
        // Configure text field appearance
        self.placeholderString = "Search metadata"
        self.isBordered = true
        self.isBezeled = true
        self.bezelStyle = .roundedBezel
        self.drawsBackground = true
        self.translatesAutoresizingMaskIntoConstraints = false
        
        // Use notification center for text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: self
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Force activating the window when we become first responder
    override func becomeFirstResponder() -> Bool {
        // Make sure the app is active first
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = self.window {
            // Make our window active
            window.makeKeyAndOrderFront(nil)
            
            // Force window to be active
            ForceActiveWindow.shared.forceWindowActive()
        }
        
        // Call the base implementation
        let result = super.becomeFirstResponder()
        
        // Select all text for convenience
        if result {
            self.selectText(nil)
        }
        
        return result
    }
    
    // Ensure we remain first responder on click
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // Force the window to be active
        if let window = self.window, window.firstResponder != self {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(self)
            ForceActiveWindow.shared.forceWindowActive()
        }
    }
    
    // Handle text changes via control notification instead of overriding textDidChange
    @objc private func handleTextChange(_ notification: Notification) {
        if let sender = notification.object as? NSTextField, sender == self {
            onTextChange?(sender.stringValue)
        }
    }
    
    // Use notification center for text changes
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Register for text change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: self
        )
    }
    
    // Ensure we get key events
    override func keyDown(with event: NSEvent) {
        // If we're not first responder, fix that
        if let window = self.window, window.firstResponder != self {
            window.makeFirstResponder(self)
        }
        
        // Force the app to be active
        NSApp.activate(ignoringOtherApps: true)
        
        // Let normal key handling continue
        super.keyDown(with: event)
    }
}

/// A NSViewRepresentable wrapper for our PatchedSearchField
struct PatchedSearchFieldView: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> PatchedSearchField {
        let field = PatchedSearchField { newText in
            // Update the binding when text changes
            text = newText
        }
        
        // Update with initial text
        field.stringValue = text
        
        return field
    }
    
    func updateNSView(_ nsView: PatchedSearchField, context: Context) {
        // Update field value if binding changed externally
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // Ensure window is active
        ForceActiveWindow.shared.forceWindowActive()
        
        // Force focus to text field
        if let window = nsView.window, window.firstResponder != nsView {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.makeFirstResponder(nsView)
            }
        }
    }
}
