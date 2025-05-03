import SwiftUI

/// A view that explains and handles permission requests for file access
struct PermissionRequestView: View {
    /// The URL that needs permission
    let url: URL?
    
    /// Optional action to retry access
    var onRetry: (() -> Void)?
    
    /// Optional action to dismiss the view
    var onDismiss: (() -> Void)?
    
    /// Access manager for handling permissions
    @State private var accessManager = FileSystemAccessManager.shared
    
    /// Whether to show the advanced help
    @State private var showAdvancedHelp = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Spacer()
                
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            
            // Icon
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundColor(.blue)
            
            // Title
            Text("Permission Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Description
            VStack(spacing: 12) {
                Text("FileMetaView needs permission to access this file:")
                    .multilineTextAlignment(.center)
                
                if let url = url {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Text("macOS security protections prevent apps from accessing files without your permission.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 400)
            
            // Action buttons
            VStack(spacing: 12) {
                Button {
                    Task {
                        await requestPermission()
                    }
                } label: {
                    HStack {
                        Image(systemName: "lock.open")
                        Text("Grant Permission")
                    }
                    .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .keyboardShortcut(.defaultAction)
                
                if let onDismiss = onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Cancel")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    showAdvancedHelp.toggle()
                } label: {
                    Text("Show Advanced Help")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Advanced help section
            if showAdvancedHelp {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    Text("Advanced Help")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        PermissionHelpItem(
                            icon: "folder.badge.questionmark",
                            title: "Clear folder permissions",
                            description: "If you've previously denied access, try accessing the file from a different location."
                        )
                        
                        PermissionHelpItem(
                            icon: "folder.badge.plus",
                            title: "Move the file",
                            description: "Try moving the file to your Documents or Downloads folder and selecting it again."
                        )
                        
                        PermissionHelpItem(
                            icon: "shield.lefthalf.fill",
                            title: "Check Privacy Settings",
                            description: "Make sure FileMetaView has full disk access in System Preferences > Security & Privacy > Privacy."
                        )
                    }
                    .padding(.leading, 4)
                }
                .padding()
                .frame(maxWidth: 450)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.05))
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: showAdvancedHelp)
        .frame(width: 500)
    }
    
    /// Request permission for the file
    @MainActor
    private func requestPermission() async {
        guard let url = url else {
            onDismiss?()
            return
        }
        
        let granted = await accessManager.requestPermission(for: url)
        
        if granted {
            // If permission was granted, retry the operation
            onRetry?()
        }
        
        // Dismiss regardless of outcome - if permission was denied,
        // the error handler will show the appropriate error
        onDismiss?()
    }
}

/// Helper view for permission help items
struct PermissionHelpItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Extensions

extension View {
    /// Present a permission request modal
    /// - Parameters:
    ///   - isPresented: Binding to control the presentation
    ///   - url: The URL that needs permission
    ///   - onRetry: Action to retry after permission is granted
    /// - Returns: View with modal permission request
    func permissionRequestModal(
        isPresented: Binding<Bool>,
        url: URL?,
        onRetry: @escaping () -> Void
    ) -> some View {
        self.overlay(
            ZStack {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    PermissionRequestView(
                        url: url,
                        onRetry: onRetry,
                        onDismiss: {
                            withAnimation {
                                isPresented.wrappedValue = false
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
struct PermissionRequestView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PermissionRequestView(
                url: URL(string: "file:///Users/username/Documents/important-file.pdf"),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Standard View")
            
            Color.gray.opacity(0.3)
                .frame(width: 600, height: 400)
                .permissionRequestModal(
                    isPresented: .constant(true),
                    url: URL(string: "file:///Users/username/Documents/important-file.pdf"),
                    onRetry: {}
                )
                .previewDisplayName("Modal Presentation")
        }
    }
}
*/
