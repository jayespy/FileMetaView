import SwiftUI
import UniformTypeIdentifiers

/// A view that provides information and help for unsupported file types
struct UnsupportedFileTypeView: View {
    /// The URL of the unsupported file
    let url: URL?
    
    /// Optional action to dismiss the view
    var onDismiss: (() -> Void)?
    
    /// Optional action to retry with the file (if implementing fallback extractors)
    var onTryAnyway: (() -> Void)?
    
    /// Whether to show detailed supported types
    @State private var showingSupportedTypes = false
    
    /// File service for accessing supported file types
    private let fileService: FileSelectionService = FileSystemSelectionService()
    
    /// The UTI string of the file if available
    var fileUTI: String? {
        guard let url = url else { return nil }
        return try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
    }
    
    /// The UTType if available
    var utType: UTType? {
        guard let uti = fileUTI else { return nil }
        return UTType(uti)
    }
    
    /// The file extension
    var fileExtension: String? {
        url?.pathExtension
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Close button
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
            Image(systemName: "doc.badge.questionmark")
                .font(.system(size: 56))
                .foregroundColor(.orange)
            
            // Title and file information
            VStack(spacing: 8) {
                Text("Unsupported File Type")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let url = url {
                    Text(url.lastPathComponent)
                        .font(.headline)
                }
                
                // File type information
                if let utType = utType {
                    HStack(spacing: 6) {
                        Text("Type:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(utType.localizedDescription ?? utType.identifier)
                            .font(.subheadline)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                } else if let fileExtension = fileExtension {
                    HStack(spacing: 6) {
                        Text("Extension:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(fileExtension)
                            .font(.subheadline)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Description
            Text("FileMetaView doesn't currently support this file type for metadata extraction.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Please select a supported file type such as image, document, audio, or video files.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Action buttons
            VStack(spacing: 12) {
                // Try anyway button (if fallback extractors are available)
                if let onTryAnyway = onTryAnyway {
                    Button(action: onTryAnyway) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Try Basic Extraction Anyway")
                        }
                        .frame(minWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut(.defaultAction)
                }
                
                // Show supported types button
                Button {
                    withAnimation {
                        showingSupportedTypes.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: showingSupportedTypes ? "chevron.up" : "chevron.down")
                        Text(showingSupportedTypes ? "Hide Supported Types" : "Show Supported Types")
                    }
                    .frame(minWidth: 220)
                }
                .buttonStyle(.bordered)
                
                // Dismiss button
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .frame(minWidth: 220)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            
            // Supported file types
            if showingSupportedTypes {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supported File Types")
                        .font(.headline)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            SupportedTypeSection(
                                title: "Images",
                                icon: "photo",
                                color: .blue,
                                types: ["JPEG", "PNG", "TIFF", "GIF", "HEIC", "PSD"]
                            )
                            
                            SupportedTypeSection(
                                title: "Documents",
                                icon: "doc.text",
                                color: .green,
                                types: ["PDF", "TXT", "RTF", "DOC", "DOCX", "Pages", "HTML", "XML"]
                            )
                            
                            SupportedTypeSection(
                                title: "Audio",
                                icon: "music.note",
                                color: .pink,
                                types: ["MP3", "WAV", "AAC", "AIFF", "M4A", "FLAC"]
                            )
                            
                            SupportedTypeSection(
                                title: "Video",
                                icon: "film",
                                color: .purple,
                                types: ["MP4", "MOV", "AVI", "MKV", "M4V", "WMV"]
                            )
                            
                            SupportedTypeSection(
                                title: "Archives",
                                icon: "archivebox",
                                color: .gray,
                                types: ["ZIP", "DMG", "ISO"]
                            )
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 200)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding()
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
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .frame(width: 500)
    }
}

/// Helper view for displaying a section of supported file types
struct SupportedTypeSection: View {
    let title: String
    let icon: String
    let color: Color
    let types: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            Text(types.joined(separator: ", "))
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Present an unsupported file type modal
    /// - Parameters:
    ///   - isPresented: Binding to control the presentation
    ///   - url: The URL of the unsupported file
    ///   - onTryAnyway: Action to try extraction anyway (optional)
    /// - Returns: View with modal unsupported file type dialog
    func unsupportedFileTypeModal(
        isPresented: Binding<Bool>,
        url: URL?,
        onTryAnyway: (() -> Void)? = nil
    ) -> some View {
        self.overlay(
            ZStack {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    UnsupportedFileTypeView(
                        url: url,
                        onDismiss: {
                            withAnimation {
                                isPresented.wrappedValue = false
                            }
                        },
                        onTryAnyway: onTryAnyway
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
struct UnsupportedFileTypeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UnsupportedFileTypeView(
                url: URL(string: "file:///Users/username/Documents/file.xyz"),
                onDismiss: {},
                onTryAnyway: {}
            )
            .previewDisplayName("Standard View")
            
            Color.gray.opacity(0.3)
                .frame(width: 600, height: 400)
                .unsupportedFileTypeModal(
                    isPresented: .constant(true),
                    url: URL(string: "file:///Users/username/Documents/file.xyz"),
                    onTryAnyway: {}
                )
                .previewDisplayName("Modal Presentation")
        }
    }
}
*/
