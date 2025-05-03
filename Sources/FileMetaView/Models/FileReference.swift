import Foundation
import AppKit
import UniformTypeIdentifiers

/// Model representing a selected file in the application
struct FileReference: Identifiable, Hashable {
    /// The URL of the file
    let url: URL
    
    /// The name of the file
    let name: String
    
    /// The file type (UTI - Uniform Type Identifier)
    let type: String
    
    /// The icon associated with the file type
    let icon: NSImage?
    
    /// Unique identifier for the file (uses the URL's absoluteString)
    var id: String {
        url.absoluteString
    }
    
    /// File creation date
    let creationDate: Date?
    
    /// File modification date
    let modificationDate: Date?
    
    /// File size in bytes
    let size: Int64
    
    /// File extension
    var fileExtension: String {
        url.pathExtension
    }
    
    /// Initialize with a URL and fetch basic metadata
    /// - Parameter url: The URL of the file to reference
    init(url: URL) {
        self.url = url
        
        // Extract file name from URL
        self.name = url.lastPathComponent
        
        // Try to get file type
        if let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            self.type = typeIdentifier
        } else {
            // Default to generic file type if we can't determine
            self.type = "public.data"
        }
        
        // Get the icon for the file
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // Get basic file attributes
        let resourceKeys: Set<URLResourceKey> = [
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]
        
        if let resourceValues = try? url.resourceValues(forKeys: resourceKeys) {
            self.creationDate = resourceValues.creationDate
            self.modificationDate = resourceValues.contentModificationDate
            self.size = Int64(resourceValues.fileSize ?? 0)
        } else {
            self.creationDate = nil
            self.modificationDate = nil
            self.size = 0
        }
    }
    
    /// Provides a user-friendly display of the file size
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Provides a formatted file type description
    var typeDescription: String {
        let descriptor = UTType(self.type) ?? UTType.data
        return descriptor.localizedDescription ?? "Unknown"
    }
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    // MARK: - Equatable Conformance
    
    static func == (lhs: FileReference, rhs: FileReference) -> Bool {
        return lhs.url == rhs.url
    }
}

// MARK: - Extensions and Helpers

extension FileReference {
    /// Creates a copy of the file reference with updated metadata
    /// - Returns: A new FileReference with fresh metadata
    func refreshMetadata() -> FileReference {
        return FileReference(url: self.url)
    }
    
    /// Checks if a file is accessible (exists and can be read)
    /// - Returns: Boolean indicating if the file is accessible
    func isAccessible() -> Bool {
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    /// Helper to check if the file is an image
    var isImage: Bool {
        let imageTypes = ["public.image", "public.jpeg", "public.png", "public.tiff"]
        return imageTypes.contains { self.type.contains($0) }
    }
    
    /// Helper to check if the file is an audio file
    var isAudio: Bool {
        let audioTypes = ["public.audio", "public.mp3", "public.wav"]
        return audioTypes.contains { self.type.contains($0) }
    }
    
    /// Helper to check if the file is a video file
    var isVideo: Bool {
        let videoTypes = ["public.movie", "public.video", "public.mpeg4"]
        return videoTypes.contains { self.type.contains($0) }
    }
    
    /// Helper to check if the file is a document
    var isDocument: Bool {
        let documentTypes = ["public.text", "public.rtf", "public.pdf", "com.apple.iwork"]
        return documentTypes.contains { self.type.contains($0) }
    }
}
