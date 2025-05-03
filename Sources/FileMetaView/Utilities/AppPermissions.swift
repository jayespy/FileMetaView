import Foundation
import AppKit

/// Manages application permissions for file access
class AppPermissions {
    /// Singleton instance
    static let shared = AppPermissions()
    
    /// File system access manager for handling permissions
    private let accessManager = FileSystemAccessManager.shared
    
    /// Private initializer for singleton
    private init() {}
    
    /// Application bundle ID for permissions
    let bundleIdentifier = "com.example.FileMetaView"
    
    /// Application version
    let appVersion = AppConfiguration.version
    
    /// Permission descriptions for user prompts
    let permissionDescriptions = [
        "NSFileProviderDomainUsageDescription": "FileMetaView needs access to read file metadata.",
        "NSDocumentsFolderUsageDescription": "FileMetaView needs access to your documents to read their metadata.",
        "NSDesktopFolderUsageDescription": "FileMetaView needs access to your desktop to read metadata of files located there.",
        "NSDownloadsFolderUsageDescription": "FileMetaView needs access to your downloads folder to read metadata of files located there.",
        "NSOpenPanelChooserDescription": "Select a file to view its metadata",
        "NSAppleEventsUsageDescription": "FileMetaView needs to interact with Finder to access file metadata."
    ]
    
    /// Request permission to access the specified URL
    /// - Parameter url: The URL to request access for
    /// - Returns: Bool indicating if access was granted
    @MainActor
    func requestAccessForURL(_ url: URL) async -> Bool {
        // Delegate to FileSystemAccessManager
        return await accessManager.requestPermission(for: url)
    }
    
    /// Request access for standard directories
    /// - Parameter directory: FileManager search path directory
    /// - Returns: Bool indicating if access was granted
    @MainActor
    func requestAccessForDirectory(_ directory: FileManager.SearchPathDirectory) async -> Bool {
        // Delegate to FileSystemAccessManager
        return await accessManager.requestAccessForDirectory(directory)
    }
    
    /// Stop accessing a previously-accessed security scoped resource
    /// - Parameter url: The URL to stop accessing
    func stopAccessingURL(_ url: URL) {
        accessManager.stopAccessingSecurityScopedResource(url)
    }
    
    /// Check if the application has bookmark or security scoped access to a URL
    /// - Parameter url: URL to check
    /// - Returns: Bool indicating if access is available
    func hasAccessToURL(_ url: URL) -> Bool {
        return accessManager.canAccessFile(url)
    }
    
    /// Creates a bookmark for persistent access to a URL
    /// - Parameter url: The URL to bookmark
    /// - Returns: Boolean indicating if bookmarking was successful
    func createBookmarkForURL(_ url: URL) -> Bool {
        return accessManager.createBookmarkForURL(url)
    }
    
    /// Removes a bookmark for a URL
    /// - Parameter url: The URL to remove the bookmark for
    /// - Returns: Boolean indicating if removal was successful
    func removeBookmarkForURL(_ url: URL) -> Bool {
        return accessManager.removeBookmarkForURL(url)
    }
    
    /// Clear all saved bookmarks
    func clearAllBookmarks() {
        accessManager.clearAllBookmarks()
    }
}
