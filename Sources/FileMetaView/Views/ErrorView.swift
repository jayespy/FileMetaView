import SwiftUI

/// A standalone view for displaying user-friendly error messages
struct ErrorView: View {
    /// The error to display
    let error: FileAccessError
    
    /// Action to dismiss the error
    var onDismiss: (() -> Void)?
    
    /// Action to retry the operation that caused the error
    var onRetry: (() -> Void)?
    
    /// State for animation
    @State private var isAnimating = false
    
    /// State for permission request view
    @State private var showingPermissionRequest = false
    
    /// URL for permission request
    @State private var permissionRequestURL: URL? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: errorIconName)
                .font(.system(size: 56))
                .foregroundColor(errorColor)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            // Error message
            VStack(spacing: 12) {
                Text(errorTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Recovery suggestion
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .frame(maxWidth: 500)
            }
            
            // Action buttons
            HStack(spacing: 20) {
                // Dismiss button
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Dismiss")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Specialized permission button for permission errors
                if case .permissionDenied(let url, _) = error {
                    Button {
                        showPermissionRequestView(for: url)
                    } label: {
                        HStack {
                            Image(systemName: "lock.open")
                            Text("Request Permission")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                // Specialized access revoked button
                else if case .accessRevoked(let url) = error {
                    Button {
                        showPermissionRequestView(for: url)
                    } label: {
                        HStack {
                            Image(systemName: "key")
                            Text("Restore Access")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                // Specialized insufficient permissions button
                else if case .insufficientPermissions = error {
                    Button {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                    } label: {
                        HStack {
                            Image(systemName: "shield")
                            Text("Open Security Settings")
                        }
                        .frame(minWidth: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                // Standard retry button for other errors
                else if let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(errorColor.opacity(0.8))
                }
            }
            .padding(.top, 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(errorColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            isAnimating = true
        }
        .permissionRequestModal(
            isPresented: $showingPermissionRequest,
            url: permissionRequestURL,
            onRetry: {
                onRetry?()
            }
        )
    }
    
    /// Return user-friendly title for the error
    private var errorTitle: String {
        switch error {
        case .permissionDenied:
            return "Permission Denied"
        case .fileNotFound:
            return "File Not Found"
        case .unsupportedFileType:
            return "Unsupported File Type"
        case .readError:
            return "Error Reading File"
        case .metadataExtractionFailed:
            return "Metadata Extraction Failed"
        case .operationCancelled:
            return "Operation Cancelled"
        case .fileTooLarge:
            return "File Too Large"
        case .timeout:
            return "Operation Timed Out"
        case .accessRevoked:
            return "Access Revoked"
        case .insufficientPermissions:
            return "Insufficient Permissions"
        case .unknown:
            return "Unexpected Error"
        }
    }
    
    /// Return an appropriate icon for the error type
    private var errorIconName: String {
        switch error {
        case .permissionDenied:
            return "lock.shield"
        case .fileNotFound:
            return "doc.questionmark"
        case .unsupportedFileType:
            return "doc.badge.questionmark"
        case .readError:
            return "doc.text.magnifyingglass"
        case .metadataExtractionFailed:
            return "doc.text.viewfinder"
        case .operationCancelled:
            return "xmark.circle"
        case .fileTooLarge:
            return "doc.on.doc.fill"
        case .timeout:
            return "timer"
        case .accessRevoked:
            return "key.slash"
        case .insufficientPermissions:
            return "lock.open"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }
    
    /// Return an appropriate color for the error type
    private var errorColor: Color {
        switch error {
        case .operationCancelled:
            return .gray
        case .fileNotFound, .unsupportedFileType:
            return .orange
        case .permissionDenied, .accessRevoked, .insufficientPermissions:
            return .blue
        case .readError, .metadataExtractionFailed, .fileTooLarge, .timeout, .unknown:
            return .red
        }
    }
    
    /// Shows the permission request view for the given URL
    private func showPermissionRequestView(for url: URL?) {
        permissionRequestURL = url
        showingPermissionRequest = true
    }
}

// MARK: - View Modifiers

extension View {
    /// Show an ErrorView as a modal overlay
    /// - Parameters:
    ///   - isPresented: Binding to control the presentation
    ///   - error: The error to display
    ///   - onDismiss: Action to dismiss the error
    ///   - onRetry: Optional action to retry the operation
    /// - Returns: View with modal error presentation
    func errorModal(
        isPresented: Binding<Bool>,
        error: FileAccessError?,
        onDismiss: @escaping () -> Void,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        self.overlay(
            ZStack {
                if isPresented.wrappedValue, let error = error {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    ErrorView(
                        error: error,
                        onDismiss: {
                            withAnimation {
                                isPresented.wrappedValue = false
                                onDismiss()
                            }
                        },
                        onRetry: onRetry.map { action in
                            {
                                withAnimation {
                                    isPresented.wrappedValue = false
                                    action()
                                }
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPresented.wrappedValue)
        )
    }
}

// MARK: - Previews

// Preview disabled for compatibility
/*
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Permission denied error
            ErrorView(
                error: FileAccessError.permissionDenied(URL(string: "file:///Users/example.txt"), nil),
                onDismiss: {},
                onRetry: {}
            )
            .frame(width: 500, height: 400)
            .previewDisplayName("Permission Denied")
            
            // File not found error
            ErrorView(
                error: FileAccessError.fileNotFound(URL(string: "file:///Users/missing.txt"), nil),
                onDismiss: {},
                onRetry: {}
            )
            .frame(width: 500, height: 400)
            .previewDisplayName("File Not Found")
            
            // Modal presentation example
            Color.white
                .frame(width: 600, height: 400)
                .errorModal(
                    isPresented: .constant(true),
                    error: FileAccessError.unsupportedFileType(URL(string: "file:///Users/example.bin"), nil),
                    onDismiss: {},
                    onRetry: {}
                )
                .previewDisplayName("Modal Presentation")
        }
    }
}
*/
