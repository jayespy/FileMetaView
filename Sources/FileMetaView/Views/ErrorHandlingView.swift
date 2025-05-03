import SwiftUI

/// A reusable view component for displaying error messages
struct ErrorHandlingView<AdditionalContent: View>: View {
    /// The error to display
    let error: FileAccessError
    
    /// Action to dismiss the error
    let onDismiss: () -> Void
    
    /// Optional additional content to display below the error message
    let additionalContent: AdditionalContent
    
    /// Initialize with error and dismiss action
    /// - Parameters:
    ///   - error: The error to display
    ///   - onDismiss: Action to dismiss the error
    ///   - additionalContent: Additional content to display below the error
    init(
        error: FileAccessError,
        onDismiss: @escaping () -> Void,
        @ViewBuilder additionalContent: () -> AdditionalContent
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.additionalContent = additionalContent()
    }
    
    /// Initialize with error and dismiss action, no additional content
    /// - Parameters:
    ///   - error: The error to display
    ///   - onDismiss: Action to dismiss the error
    init(
        error: FileAccessError,
        onDismiss: @escaping () -> Void
    ) where AdditionalContent == EmptyView {
        self.error = error
        self.onDismiss = onDismiss
        self.additionalContent = EmptyView()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Error header
            HStack {
                errorIcon
                    .foregroundColor(errorColor)
                    .font(.title2)
                
                Text(error.localizedDescription)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Recovery suggestion if available
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // Additional content if provided
            additionalContent
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(errorBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(errorColor.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    /// Return an appropriate icon for the error type
    private var errorIcon: some View {
        Image(systemName: errorIconName)
    }
    
    /// Return the icon name based on error type
    private var errorIconName: String {
        switch error {
        case .permissionDenied:
            return "lock.fill"
        case .fileNotFound:
            return "questionmark.folder.fill"
        case .unsupportedFileType:
            return "doc.fill.badge.questionmark"
        case .readError:
            return "doc.text.fill.badge.exclamationmark"
        case .metadataExtractionFailed:
            return "doc.plaintext.fill.badge.exclamationmark"
        case .operationCancelled:
            return "xmark.circle.fill"
        case .fileTooLarge:
            return "arrow.up.forward.circle.fill"
        case .timeout:
            return "clock.fill"
        case .accessRevoked:
            return "nosign"
        case .insufficientPermissions:
            return "exclamationmark.shield.fill"
        case .unknown:
            return "exclamationmark.triangle.fill"
        }
    }
    
    /// Return an appropriate color for the error severity
    private var errorColor: Color {
        switch error {
        case .operationCancelled:
            return .secondary
        case .fileNotFound, .unsupportedFileType:
            return .orange
        case .permissionDenied, .readError, .metadataExtractionFailed, 
             .fileTooLarge, .timeout, .accessRevoked, .insufficientPermissions,
             .unknown:
            return .red
        }
    }
    
    /// Return an appropriate background color based on error color
    private var errorBackgroundColor: Color {
        errorColor.opacity(0.1)
    }
}

// MARK: - View Extension

extension View {
    /// Add an error overlay to a view
    /// - Parameters:
    ///   - error: Optional error to display
    ///   - onDismiss: Action to dismiss the error
    ///   - alignment: Alignment of the error view
    ///   - offset: Offset for positioning the error view
    /// - Returns: Modified view with error overlay
    func errorOverlay<AdditionalContent: View>(
        _ error: FileAccessError?,
        onDismiss: @escaping () -> Void,
        alignment: Alignment = .top,
        offset: CGPoint = CGPoint(x: 0, y: 40),
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent
    ) -> some View {
        self.overlay(
            Group {
                if let error = error {
                    ErrorHandlingView(
                        error: error,
                        onDismiss: onDismiss,
                        additionalContent: additionalContent
                    )
                    .padding()
                    .offset(x: offset.x, y: offset.y)
                    .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: error != nil),
            alignment: alignment
        )
    }
    
    /// Add an error overlay to a view (simplified version)
    /// - Parameters:
    ///   - error: Optional error to display
    ///   - onDismiss: Action to dismiss the error
    ///   - alignment: Alignment of the error view
    ///   - offset: Offset for positioning the error view
    /// - Returns: Modified view with error overlay
    func errorOverlay(
        _ error: FileAccessError?,
        onDismiss: @escaping () -> Void,
        alignment: Alignment = .top,
        offset: CGPoint = CGPoint(x: 0, y: 40)
    ) -> some View {
        self.errorOverlay(
            error,
            onDismiss: onDismiss,
            alignment: alignment,
            offset: offset
        ) {
            EmptyView()
        }
    }
}

// MARK: - Previews

// Preview disabled for compatibility
/*
struct ErrorHandlingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Application Content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 400)
        .errorOverlay(
            FileAccessError.permissionDenied(URL(string: "file:///Users/example.txt"), nil),
            onDismiss: {}
        )
        
        VStack(spacing: 20) {
            ErrorHandlingView(
                error: FileAccessError.permissionDenied(URL(string: "file:///Users/example.txt"), nil),
                onDismiss: {}
            )
            
            ErrorHandlingView(
                error: FileAccessError.fileNotFound(URL(string: "file:///Users/missing.txt"), nil),
                onDismiss: {}
            )
            
            ErrorHandlingView(
                error: FileAccessError.unsupportedFileType(URL(string: "file:///Users/example.bin"), nil),
                onDismiss: {}
            )
            
            ErrorHandlingView(
                error: FileAccessError.operationCancelled,
                onDismiss: {}
            )
        }
        .padding()
    }
}
*/
