import SwiftUI

/// A small popup view to confirm that content has been copied
struct CopyConfirmationView: View {
    /// Whether the view is showing
    @Binding var isShowing: Bool
    
    /// The message to display
    let message: String
    
    /// Timer for auto-dismissal
    @State private var dismissTimer: Timer? = nil
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.green)
                    .imageScale(.medium)
                
                Text(message)
                    .font(.callout)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .onAppear {
            // Automatically dismiss after 2 seconds
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowing = false
                }
            }
        }
        .onDisappear {
            dismissTimer?.invalidate()
            dismissTimer = nil
        }
    }
}

/// View modifier to add a copy confirmation popup
struct CopyConfirmationModifier: ViewModifier {
    /// Whether the confirmation is showing
    @Binding var isShowing: Bool
    
    /// The message to display
    let message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                VStack {
                    CopyConfirmationView(isShowing: $isShowing, message: message)
                        .padding(.top, 20)
                    
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
}

extension View {
    /// Add a copy confirmation popup to this view
    /// - Parameters:
    ///   - isShowing: Binding to control visibility
    ///   - message: Message to display
    /// - Returns: View with copy confirmation
    func copyConfirmation(isShowing: Binding<Bool>, message: String = "Copied to clipboard") -> some View {
        self.modifier(CopyConfirmationModifier(isShowing: isShowing, message: message))
    }
}