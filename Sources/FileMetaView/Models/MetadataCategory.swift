import Foundation
import SwiftUI

/// Categories for organizing metadata fields
enum MetadataCategory: String, CaseIterable, Identifiable {
    // Core categories
    case basic = "basic"               // Core file information (name, path, size, dates)
    case permissions = "permissions"   // File permissions and access rights
    case filesystem = "filesystem"     // Filesystem-specific attributes
    
    // Content-specific categories
    case document = "document"         // Document-specific metadata (author, title, etc.)
    case image = "image"               // Image-specific metadata (dimensions, DPI, EXIF)
    case audio = "audio"               // Audio-specific metadata (duration, bitrate, artist)
    case video = "video"               // Video-specific metadata (resolution, codec, etc.)
    case archive = "archive"           // Archive-specific metadata (compression, entries)
    
    // Other categories
    case system = "system"             // System-specific attributes (spotlight, quarantine)
    case extended = "extended"         // Extended attributes
    case custom = "custom"             // App-specific or user-defined metadata
    
    /// Identifier for Identifiable conformance
    var id: String { self.rawValue }
    
    /// Get a sort order for categories to ensure a logical display order
    var sortOrder: Int {
        switch self {
        case .basic:        return 0
        case .filesystem:   return 1
        case .permissions:  return 2
        case .document:     return 3
        case .image:        return 4
        case .audio:        return 5
        case .video:        return 6
        case .archive:      return 7
        case .system:       return 8
        case .extended:     return 9
        case .custom:       return 10
        }
    }
    
    /// Display name for the category
    var displayName: String {
        switch self {
        case .basic:        return "Basic Information"
        case .permissions:  return "Permissions & Access"
        case .filesystem:   return "Filesystem Attributes"
        case .document:     return "Document Properties"
        case .image:        return "Image Properties"
        case .audio:        return "Audio Properties"
        case .video:        return "Video Properties"
        case .archive:      return "Archive Properties"
        case .system:       return "System Attributes"
        case .extended:     return "Extended Attributes"
        case .custom:       return "Custom Metadata"
        }
    }
    
    /// Description for the category
    var description: String {
        switch self {
        case .basic:        return "Core file information such as name, size, and dates."
        case .permissions:  return "File permissions, ownership, and access control information."
        case .filesystem:   return "Filesystem-specific metadata like inodes and allocation."
        case .document:     return "Document-specific metadata like author, title, and pages."
        case .image:        return "Image metadata including dimensions, color profile, and EXIF data."
        case .audio:        return "Audio metadata including artist, album, and encoding details."
        case .video:        return "Video metadata including resolution, framerate, and codec."
        case .archive:      return "Archive metadata including compression method and entry count."
        case .system:       return "System-level attributes like Spotlight indexing and quarantine status."
        case .extended:     return "Extended attributes provided by the filesystem or applications."
        case .custom:       return "Custom or user-defined metadata fields."
        }
    }
    
    /// Color associated with this category for UI display
    var color: Color {
        switch self {
        case .basic:        return .blue
        case .permissions:  return .red
        case .filesystem:   return .gray
        case .document:     return .brown
        case .image:        return .pink
        case .audio:        return .purple
        case .video:        return .orange
        case .archive:      return .yellow
        case .system:       return .black
        case .extended:     return .green
        case .custom:       return .indigo
        }
    }
    
    /// SF Symbol icon name associated with this category
    var iconName: String {
        switch self {
        case .basic:        return "info.circle"
        case .permissions:  return "lock"
        case .filesystem:   return "externaldrive"
        case .document:     return "doc"
        case .image:        return "photo"
        case .audio:        return "music.note"
        case .video:        return "film"
        case .archive:      return "archivebox"
        case .system:       return "gearshape"
        case .extended:     return "plus.square"
        case .custom:       return "tag"
        }
    }
    
    /// Determine the appropriate category for a metadata key
    /// - Parameter key: The metadata key to categorize
    /// - Returns: The most appropriate category for the key
    static func categorize(key: String) -> MetadataCategory {
        let lowercasedKey = key.lowercased()
        
        // Filesystem and ownership keys
        if lowercasedKey.contains("inode") || lowercasedKey.contains("alloc") || 
           lowercasedKey.contains("volume") || lowercasedKey.contains("filesystem") || 
           lowercasedKey.contains("disk") || lowercasedKey.contains("file system") {
            return .filesystem
        }
        
        // Permission-related keys
        if lowercasedKey.contains("permission") || lowercasedKey.contains("owner") || 
           lowercasedKey.contains("group") || lowercasedKey.contains("mode") || 
           lowercasedKey.contains("protection") || lowercasedKey.contains("access") || 
           lowercasedKey.contains("right") || lowercasedKey.contains("priv") {
            return .permissions
        }
        
        // Document-specific keys
        if lowercasedKey.contains("author") || lowercasedKey.contains("creator") || 
           lowercasedKey.contains("title") || lowercasedKey.contains("subject") || 
           lowercasedKey.contains("keywords") || lowercasedKey.contains("pages") || 
           lowercasedKey.contains("word count") || lowercasedKey.contains("character count") || 
           lowercasedKey.contains("paragraph") || lowercasedKey.contains("encoding") || 
           lowercasedKey.contains("pdf") || lowercasedKey.contains("document") {
            return .document
        }
        
        // Image-specific keys
        if lowercasedKey.contains("exif") || lowercasedKey.contains("image") || 
           lowercasedKey.contains("pixel") || lowercasedKey.contains("width") || 
           lowercasedKey.contains("height") || lowercasedKey.contains("color profile") || 
           lowercasedKey.contains("camera") || lowercasedKey.contains("aperture") || 
           lowercasedKey.contains("shutter") || lowercasedKey.contains("focal") || 
           lowercasedKey.contains("iso") || lowercasedKey.contains("flash") || 
           lowercasedKey.contains("resolution") || lowercasedKey.contains("dpi") {
            return .image
        }
        
        // Audio-specific keys
        if lowercasedKey.contains("audio") || lowercasedKey.contains("song") || 
           lowercasedKey.contains("artist") || lowercasedKey.contains("album") || 
           lowercasedKey.contains("composer") || lowercasedKey.contains("genre") || 
           lowercasedKey.contains("track") || lowercasedKey.contains("year") || 
           lowercasedKey.contains("tempo") || lowercasedKey.contains("sample rate") || 
           lowercasedKey.contains("bit rate") || lowercasedKey.contains("channels") || 
           lowercasedKey.contains("duration") || lowercasedKey.contains("id3") {
            return .audio
        }
        
        // Video-specific keys
        if lowercasedKey.contains("video") || lowercasedKey.contains("movie") || 
           lowercasedKey.contains("frame rate") || lowercasedKey.contains("codec") || 
           lowercasedKey.contains("director") || lowercasedKey.contains("producer") || 
           lowercasedKey.contains("cast") || lowercasedKey.contains("episode") || 
           lowercasedKey.contains("season") || lowercasedKey.contains("show") {
            return .video
        }
        
        // Archive-specific keys
        if lowercasedKey.contains("archive") || lowercasedKey.contains("compress") || 
           lowercasedKey.contains("zip") || lowercasedKey.contains("tar") || 
           lowercasedKey.contains("entries") || lowercasedKey.contains("members") || 
           lowercasedKey.contains("extraction") {
            return .archive
        }
        
        // System-specific keys
        if lowercasedKey.contains("system") || lowercasedKey.contains("spotlight") || 
           lowercasedKey.contains("quarantine") || lowercasedKey.contains("finder") || 
           lowercasedKey.contains("kmditem") || lowercasedKey.contains("mditem") || 
           lowercasedKey.contains("com.apple") {
            return .system
        }
        
        // Custom metadata
        if lowercasedKey.contains("custom") || lowercasedKey.contains("user") || 
           lowercasedKey.contains("tag") || lowercasedKey.contains("comment") || 
           lowercasedKey.contains("note") || lowercasedKey.contains("meta") {
            return .custom
        }
        
        // Basic file information
        if lowercasedKey.contains("name") || lowercasedKey.contains("path") || 
           lowercasedKey.contains("size") || lowercasedKey.contains("date") || 
           lowercasedKey.contains("created") || lowercasedKey.contains("modified") || 
           lowercasedKey.contains("accessed") || lowercasedKey.contains("type") || 
           lowercasedKey.contains("extension") || lowercasedKey.contains("kind") || 
           lowercasedKey.contains("length") || lowercasedKey.contains("hidden") || 
           lowercasedKey.contains("label") {
            return .basic
        }
        
        // Extended attributes (if none of the above)
        if lowercasedKey.contains("xattr") || lowercasedKey.contains("attr") || 
           lowercasedKey.contains("extended") || lowercasedKey.contains("resource") {
            return .extended
        }
        
        // Default to extended attributes if no other match
        return .extended
    }
    
    /// Categorize based on file reference type in addition to key
    /// - Parameters:
    ///   - key: The metadata key to categorize
    ///   - fileReference: The file reference to help determine appropriate category
    /// - Returns: The most appropriate category for the key
    static func categorize(key: String, fileReference: FileReference) -> MetadataCategory {
        let baseCategory = categorize(key: key)
        
        // If we already have a specific category, use it
        if baseCategory != .basic && baseCategory != .extended {
            return baseCategory
        }
        
        // Otherwise, try to use the file type to refine the category
        if fileReference.isImage {
            return .image
        } else if fileReference.isAudio {
            return .audio
        } else if fileReference.isVideo {
            return .video
        } else if fileReference.isDocument {
            return .document
        }
        
        return baseCategory
    }
    
    /// Get categories that are relevant for a specific file type
    /// - Parameter fileReference: The file reference to determine relevant categories
    /// - Returns: Array of categories relevant to this file
    static func relevantCategories(for fileReference: FileReference) -> [MetadataCategory] {
        var categories: [MetadataCategory] = [.basic, .permissions, .filesystem, .system]
        
        if fileReference.isImage {
            categories.append(.image)
        }
        
        if fileReference.isAudio {
            categories.append(.audio)
        }
        
        if fileReference.isVideo {
            categories.append(.video)
        }
        
        if fileReference.isDocument {
            categories.append(.document)
        }
        
        // Add extended attributes as the last category
        categories.append(.extended)
        
        return categories
    }
}
