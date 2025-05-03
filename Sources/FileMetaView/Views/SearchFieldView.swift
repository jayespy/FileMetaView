import SwiftUI
import AppKit

/// A wrapper for NSSearchField to properly handle search input
struct SearchFieldView: NSViewRepresentable {
    @Binding var text: String
    var placeholderText: String
    
    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchFieldView
        var isFirstActivation = true
        
        init(_ parent: SearchFieldView) {
            self.parent = parent
        }
        
        /// Handle text changes
        func controlTextDidChange(_ obj: Notification) {
            guard let searchField = obj.object as? NSSearchField else { return }
            parent.text = searchField.stringValue
        }
        
        /// Handle search action
        func controlTextDidEndEditing(_ obj: Notification) {
            // No special handling needed here
        }
        
        /// Handle search field becoming active
        func controlTextDidBeginEditing(_ obj: Notification) {
            // Make sure the app is active
            NSApp.activate(ignoringOtherApps: true)
        }
        
        /// Handle search action
        @objc func search(_ sender: NSSearchField) {
            parent.text = sender.stringValue
        }
        
        /// Handle clear button
        @objc func clear(_ sender: NSSearchField) {
            parent.text = ""
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        
        // Configure the field
        searchField.placeholderString = placeholderText
        searchField.delegate = context.coordinator
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.search)
        searchField.bezelStyle = .roundedBezel
        searchField.isBordered = true
        searchField.isBezeled = true
        searchField.drawsBackground = true
        
        // Configure the search field actions directly
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        
        return searchField
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        // Update field value if it's different from binding
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // Force field to be first responder on first update
        if context.coordinator.isFirstActivation {
            context.coordinator.isFirstActivation = false
            
            // Delay to ensure window is fully set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = nsView.window {
                    // First activate the window
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                    
                    // Then make the field first responder
                    window.makeFirstResponder(nsView)
                }
            }
        }
    }
}
