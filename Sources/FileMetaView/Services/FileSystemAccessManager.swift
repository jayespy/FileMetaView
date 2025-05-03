import Foundation
import AppKit
import UniformTypeIdentifiers

/// Result type for file validation operations
enum FileValidationResult {
    /// The file is valid and supported
    case valid
    /// The file is invalid or unsupported with specific error information
    case invalid(FileAccessError)
}

/// Manager class for handling file system access permissions and security-scoped resources
class FileSystemAccessManager {
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = FileSystemAccessManager()
    
    /// Bookmarks storage key in UserDefaults
    private let bookmarksKey = "com.example.FileMetaView.bookmarks"
    
    /// Dictionary mapping URLs to access status
    private var activeAccessedResources: [URL: Bool] = [:]
    
    /// UserDefaults for persistent storage
    private let userDefaults = UserDefaults.standard
    
    /// Private initializer for singleton
    private init() {
        // Load any saved bookmarks on initialization
        restoreBookmarks()
    }
    
    // MARK: - File Access Management
    
    /// Checks if the application has permission to access a specific file
    /// - Parameter url: The URL to check permissions for
    /// - Returns: Boolean indicating if file is accessible
    func canAccessFile(_ url: URL) -> Bool {
        // Basic check using FileManager
        if FileManager.default.isReadableFile(atPath: url.path) {
            return true
        }
        
        // Try to access through security-scoped resource if basic check failed
        if let hasAccess = activeAccessedResources[url], hasAccess {
            return true
        }
        
        // Check if we have a bookmark for this URL
        return resolveBookmarkForURL(url) != nil
    }
    
    /// Requests permission to access a file
    /// - Parameter url: The URL to request access for
    /// - Returns: Boolean indicating if access was granted
    @MainActor
    func requestPermission(for url: URL) async -> Bool {
        // First, try using security-scoped resource access
        if startAccessingSecurityScopedResource(url) {
            return true
        }
        
        // If that fails, try to use NSOpenPanel to gain permission
        return await requestPermissionViaOpenPanel(for: url)
    }
    
    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL to access
    /// - Returns: Boolean indicating if access was successfully started
    func startAccessingSecurityScopedResource(_ url: URL) -> Bool {
        // Check if we already have access
        if let hasAccess = activeAccessedResources[url], hasAccess {
            return true
        }
        
        // Try to start accessing directly
        if url.startAccessingSecurityScopedResource() {
            activeAccessedResources[url] = true
            return true
        }
        
        // If that fails, try to resolve from a bookmark
        if let bookmarkURL = resolveBookmarkForURL(url), 
           bookmarkURL.startAccessingSecurityScopedResource() {
            activeAccessedResources[bookmarkURL] = true
            return true
        }
        
        return false
    }
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    func stopAccessingSecurityScopedResource(_ url: URL) {
        // Check if we have active access
        if let hasAccess = activeAccessedResources[url], hasAccess {
            url.stopAccessingSecurityScopedResource()
            activeAccessedResources[url] = false
        }
        
        // Also check if we have a bookmark for this URL
        if let bookmarkURL = resolveBookmarkForURL(url),
           let hasAccess = activeAccessedResources[bookmarkURL], hasAccess {
            bookmarkURL.stopAccessingSecurityScopedResource()
            activeAccessedResources[bookmarkURL] = false
        }
    }
    
    // MARK: - Bookmark Management
    
    /// Creates a bookmark for persistent access to a URL
    /// - Parameter url: The URL to bookmark
    /// - Returns: Boolean indicating if bookmarking was successful
    func createBookmarkForURL(_ url: URL) -> Bool {
        do {
            // Create a security-scoped bookmark
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // Save the bookmark data in UserDefaults
            saveBookmarkData(bookmarkData, forURL: url)
            return true
        } catch {
            // Log the error
            print("Failed to create bookmark for URL: \(url.path) - \(error.localizedDescription)")
            return false
        }
    }
    
    /// Resolves a bookmark to get an accessible URL
    /// - Parameter url: The original URL to find a bookmark for
    /// - Returns: The resolved URL, or nil if no bookmark exists or it cannot be resolved
    func resolveBookmarkForURL(_ url: URL) -> URL? {
        // Check if we have a bookmark for this URL
        guard let bookmarkData = getBookmarkData(forURL: url) else {
            return nil
        }
        
        do {
            // Resolve the bookmark to get a URL with security scope
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // If the bookmark is stale, update it if possible
            if isStale {
                _ = createBookmarkForURL(resolvedURL)
            }
            
            return resolvedURL
        } catch {
            // Log the error
            print("Failed to resolve bookmark for URL: \(url.path) - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Removes a bookmark for a URL
    /// - Parameter url: The URL to remove the bookmark for
    /// - Returns: Boolean indicating if removal was successful
    func removeBookmarkForURL(_ url: URL) -> Bool {
        var bookmarks = getAllBookmarks()
        
        // Remove the bookmark for this URL if it exists
        let urlPath = url.path
        var removed = false
        
        for (key, _) in bookmarks where key.hasSuffix(urlPath) {
            bookmarks.removeValue(forKey: key)
            removed = true
        }
        
        // Save the updated bookmarks
        userDefaults.set(bookmarks, forKey: bookmarksKey)
        return removed
    }
    
    /// Clear all saved bookmarks
    func clearAllBookmarks() {
        userDefaults.removeObject(forKey: bookmarksKey)
        activeAccessedResources.removeAll()
    }
    
    // MARK: - Directory Access
    
    /// Requests access to a standard system directory
    /// - Parameter directory: The directory to request access for
    /// - Returns: Boolean indicating if access was granted
    @MainActor
    func requestAccessForDirectory(_ directory: FileManager.SearchPathDirectory) async -> Bool {
        guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            return false
        }
        
        return await requestPermission(for: url)
    }
    
    /// Check if the application has sandbox permissions for the specified directory
    /// - Parameter directory: The directory to check
    /// - Returns: Boolean indicating if the directory is accessible
    func canAccessDirectory(_ directory: FileManager.SearchPathDirectory) -> Bool {
        guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            return false
        }
        
        return canAccessFile(url)
    }
    
    // MARK: - Private Helper Methods
    
    /// Request permission via NSOpenPanel
    /// - Parameter url: The URL to request access for
    /// - Returns: Boolean indicating if access was granted
    @MainActor
    private func requestPermissionViaOpenPanel(for url: URL) async -> Bool {
        // Create and configure an open panel
        let openPanel = NSOpenPanel()
        openPanel.message = "FileMetaView needs permission to access this file"
        openPanel.prompt = "Grant Access"
        openPanel.directoryURL = url.deletingLastPathComponent()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        // Present the panel
        let response = await openPanel.beginSheetModal(for: NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow())
        
        guard response == .OK, let selectedURL = openPanel.url else {
            return false
        }
        
        // Check if we selected the correct file
        if selectedURL.path == url.path {
            // Create a bookmark for this URL for future access
            _ = createBookmarkForURL(selectedURL)
            return true
        }
        
        return false
    }
    
    /// Store bookmark data in UserDefaults
    /// - Parameters:
    ///   - data: The bookmark data to store
    ///   - url: The URL associated with the bookmark
    private func saveBookmarkData(_ data: Data, forURL url: URL) {
        var bookmarks = getAllBookmarks()
        
        // Use the URL's path as a key
        let key = "\(url.lastPathComponent)_\(url.path)"
        bookmarks[key] = data
        
        userDefaults.set(bookmarks, forKey: bookmarksKey)
    }
    
    /// Retrieve bookmark data for a URL
    /// - Parameter url: The URL to get bookmark data for
    /// - Returns: The bookmark data, or nil if none exists
    private func getBookmarkData(forURL url: URL) -> Data? {
        let bookmarks = getAllBookmarks()
        let urlPath = url.path
        
        // Find a bookmark with a matching path
        for (key, data) in bookmarks where key.hasSuffix(urlPath) {
            return data
        }
        
        return nil
    }
    
    /// Get all stored bookmarks
    /// - Returns: Dictionary of bookmark keys to bookmark data
    private func getAllBookmarks() -> [String: Data] {
        return userDefaults.dictionary(forKey: bookmarksKey) as? [String: Data] ?? [:]
    }
    
    /// Restore all saved bookmarks
    private func restoreBookmarks() {
        let bookmarks = getAllBookmarks()
        
        for (_, bookmarkData) in bookmarks {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    // Update the bookmark if it's stale
                    if let newBookmarkData = try? url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        saveBookmarkData(newBookmarkData, forURL: url)
                    }
                }
            } catch {
                // Just skip invalid bookmarks
                continue
            }
        }
    }
    
    // MARK: - File Validation
    
    /// Validates if a file URL is acceptable for processing
    /// - Parameter url: The URL to validate
    /// - Returns: Boolean indicating if the file is valid
    func isValidFile(_ url: URL) -> Bool {
        // Check if the URL represents a file (not a directory)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        
        // We only want files, not directories
        guard !isDirectory.boolValue else {
            return false
        }
        
        // Check if the file size is accessible and not too large
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? NSNumber else {
                return false
            }
            
            // Check if file size is reasonable (less than 100MB by default)
            let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
            if fileSize.int64Value > maxFileSize {
                return false
            }
        } catch {
            return false
        }
        
        // Check if file type is supported
        return isFileTypeSupported(url)
    }
    
    /// Validates a file URL and provides specific information about why it's not valid
    /// - Parameter url: The URL to validate
    /// - Returns: A validation result with specific information
    func validateFile(_ url: URL) -> FileValidationResult {
        // Check if the URL represents a file (not a directory)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .invalid(.fileNotFound(url, "The file does not exist."))
        }
        
        // We only want files, not directories
        guard !isDirectory.boolValue else {
            return .invalid(.unsupportedFileType(url, "Directories are not supported."))
        }
        
        // Check if the file size is accessible and not too large
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? NSNumber else {
                return .invalid(.readError(url, nil))
            }
            
            // Check if file size is reasonable (less than 100MB by default)
            let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
            if fileSize.int64Value > maxFileSize {
                return .invalid(.fileTooLarge(url, fileSize.int64Value))
            }
        } catch {
            return .invalid(.readError(url, error))
        }
        
        // Check file type
        if !isFileTypeSupported(url) {
            // Get file type info
            var typeDescription = url.pathExtension.uppercased()
            if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
               let utType = UTType(uti) {
                typeDescription = utType.localizedDescription ?? typeDescription
            }
            
            return .invalid(.unsupportedFileType(url, "File type '\(typeDescription)' is not supported."))
        }
        
        return .valid
    }
    
    /// Checks if a file type is supported by the application
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating if the file type is supported
    func isFileTypeSupported(_ url: URL) -> Bool {
        // Get the file's UTI
        guard let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
              let utType = UTType(uti) else {
            return false
        }
        
        // Check if it conforms to any of our supported types
        // This is a basic implementation - typically the actual file types would be
        // defined elsewhere or passed in to this method
        let supportedTypes: [UTType] = [
            .item, .content, .compositeContent, // Generic types
            .text, .plainText, .html, .xml, .pdf, // Document types
            .image, .jpeg, .png, .tiff, // Image types
            .audio, .movie, .video, // Media types
            .archive, .diskImage // Archive types
        ]
        
        for supportedType in supportedTypes {
            if utType.conforms(to: supportedType) {
                return true
            }
        }
        
        return false
    }
}
