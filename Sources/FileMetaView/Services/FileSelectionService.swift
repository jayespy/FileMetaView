import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Protocol defining the interface for file selection operations
protocol FileSelectionService {
    /// Presents a file selection dialog and returns the selected file reference
    /// - Returns: A FileReference object representing the selected file
    /// - Throws: FileAccessError if selection fails or is cancelled
    func selectFile() async throws -> FileReference
    
    /// Handles a file dropped onto the application
    /// - Parameter url: The URL of the dropped file
    /// - Returns: A FileReference object representing the dropped file
    /// - Throws: FileAccessError if file cannot be accessed or is invalid
    func handleFileDropped(url: URL) throws -> FileReference
    
    /// Validates if a file URL is acceptable for processing
    /// - Parameter url: The URL to validate
    /// - Returns: Boolean indicating if the file is valid
    func isValidFile(_ url: URL) -> Bool
    
    /// Validates a file URL and provides detailed information
    /// - Parameter url: The URL to validate
    /// - Returns: A validation result with specific information
    func validateFile(_ url: URL) -> FileValidationResult
    
    /// Checks if the application has access permissions for a file
    /// - Parameter url: The URL to check permissions for
    /// - Returns: Boolean indicating if file is accessible
    func canAccessFile(_ url: URL) -> Bool
    
    /// Requests permission to access a file if needed
    /// - Parameter url: The URL to request access for
    /// - Returns: Boolean indicating if access was granted
    /// - Throws: FileAccessError if permission request fails
    func requestPermission(for url: URL) async throws -> Bool
    
    /// Gets a list of supported file types for selection
    /// - Returns: Array of supported UTI strings
    func supportedFileTypes() -> [String]
    
    /// Custom file type filter for file selection dialogs
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating if file type is supported
    func fileTypeFilter(_ url: URL) -> Bool
}

// MARK: - Default Implementations

extension FileSelectionService {
    /// Default implementation for supported file types
    func supportedFileTypes() -> [String] {
        return [
            // Common file types
            "public.item",          // Any file
            "public.content",       // Any document
            "public.composite-content", // Any composite document
            "public.archive",       // Archives
            "public.disk-image",    // Disk images
            
            // Document types
            "public.text",          // Text
            "public.plain-text",    // Plain text
            "public.rtf",           // Rich text
            "public.html",          // HTML
            "public.xml",           // XML
            "public.source-code",   // Source code
            "com.adobe.pdf",        // PDF
            "com.apple.property-list", // Property lists
            
            // Image types
            "public.image",         // Images
            "public.jpeg",          // JPEG
            "public.png",           // PNG
            "public.tiff",          // TIFF
            "com.adobe.photoshop-image", // Photoshop
            "com.adobe.illustrator.ai-image", // Illustrator
            
            // Audio types
            "public.audio",         // Audio
            "public.mp3",           // MP3
            "public.mpeg-4-audio",  // AAC/MP4 audio
            "public.wav",           // WAV
            "com.apple.coreaudio-format", // CoreAudio
            
            // Video types
            "public.movie",         // Movies
            "public.video",         // Video
            "public.avi",           // AVI
            "public.mpeg",          // MPEG
            "public.mpeg-4",        // MP4
            
            // Office document types
            "com.microsoft.word.doc", // Word documents
            "org.openxmlformats.wordprocessingml.document", // DOCX
            "com.microsoft.excel.xls", // Excel spreadsheets
            "org.openxmlformats.spreadsheetml.sheet", // XLSX
            "com.microsoft.powerpoint.ppt", // PowerPoint
            "org.openxmlformats.presentationml.presentation", // PPTX
            
            // Apple document types
            "com.apple.iwork.pages.pages", // Pages
            "com.apple.iwork.numbers.numbers", // Numbers
            "com.apple.iwork.keynote.keynote", // Keynote
        ]
    }
    
    /// Default implementation for file type filter
    func fileTypeFilter(_ url: URL) -> Bool {
        guard let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
            return false
        }
        
        // Check if the UTI conforms to any of our supported types
        if let utType = UTType(uti) {
            for supportedType in supportedFileTypes() {
                if let supportedUTType = UTType(supportedType), utType.conforms(to: supportedUTType) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Default implementation for file validation
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
        
        // Check if the file size is accessible and not too large (100MB limit)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? NSNumber else {
                return false
            }
            
            // Check if file size is reasonable (less than 100MB by default)
            // This can be adjusted based on application requirements
            let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
            if fileSize.int64Value > maxFileSize {
                return false
            }
        } catch {
            return false
        }
        
        // Check if file type is supported
        return fileTypeFilter(url)
    }
    
    /// Default implementation for checking file access
    func canAccessFile(_ url: URL) -> Bool {
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    /// Default implementation for validating files with detailed results
    func validateFile(_ url: URL) -> FileValidationResult {
        return FileSystemAccessManager.shared.validateFile(url)
    }
}

// MARK: - FileSystemSelectionService Implementation

/// Concrete implementation of FileSelectionService using NSOpenPanel
class FileSystemSelectionService: FileSelectionService {
    
    /// Maximum file size limit in bytes (default: 100MB)
    private let maxFileSize: Int64
    
    /// File system access manager for handling permissions
    private let accessManager: FileSystemAccessManager
    
    /// Initialize with optional custom file size limit
    /// - Parameters:
    ///   - maxFileSize: Maximum file size in bytes (default: 100MB)
    ///   - accessManager: Manager for handling file system access permissions
    init(
        maxFileSize: Int64 = 100 * 1024 * 1024,
        accessManager: FileSystemAccessManager = FileSystemAccessManager.shared
    ) {
        self.maxFileSize = maxFileSize
        self.accessManager = accessManager
    }
    
    /// Presents a file selection dialog and returns the selected file reference
    /// - Returns: A FileReference object representing the selected file
    /// - Throws: FileAccessError if selection fails or is cancelled
    @MainActor
    func selectFile() async throws -> FileReference {
        // Create and configure the open panel
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.canCreateDirectories = false
        openPanel.prompt = "Select File"
        
        // Allow only supported file types
        openPanel.allowedContentTypes = supportedFileTypes().compactMap { UTType($0) }
        
        // Present the panel modally
        let response = await openPanel.beginSheetModal(for: NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow ?? NSWindow())
        
        // Handle the response
        switch response {
        case .OK:
            // Ensure we have a URL
            guard let url = openPanel.url else {
                throw FileAccessError.fileNotFound(nil, "No file was selected")
            }
            
            // Validate the selected file
            let validationResult = accessManager.validateFile(url)
            switch validationResult {
            case .valid:
                break // File is valid, continue
            case .invalid(let error):
                throw error // Throw the specific error
            }
            
            // Check if file is accessible
            if !accessManager.canAccessFile(url) {
                // Try to request permission
                let permissionGranted = await accessManager.requestPermission(for: url)
                if !permissionGranted {
                    throw FileAccessError.permissionDenied(url, "Permission to access the file was denied")
                }
                
                // Create a bookmark for future access
                _ = accessManager.createBookmarkForURL(url)
            }
            
            // Create and return a FileReference
            return FileReference(url: url)
            
        case .cancel:
            throw FileAccessError.operationCancelled("File selection cancelled by user")
            
        default:
            throw FileAccessError.unknown(nil)
        }
    }
    
    /// Handles a file dropped onto the application
    /// - Parameter url: The URL of the dropped file
    /// - Returns: A FileReference object representing the dropped file
    /// - Throws: FileAccessError if file cannot be accessed or is invalid
    func handleFileDropped(url: URL) throws -> FileReference {
        // Validate the file with detailed results
        let validationResult = accessManager.validateFile(url)
        switch validationResult {
        case .valid:
            break // Continue processing
        case .invalid(let error):
            throw error // Throw the specific error
        }
        
        // Check if file is accessible
        guard accessManager.canAccessFile(url) else {
            throw FileAccessError.permissionDenied(url, "Permission to access the dropped file was denied")
        }
        
        // Create a bookmark for future access
        _ = accessManager.createBookmarkForURL(url)
        
        // Create and return a FileReference
        return FileReference(url: url)
    }
    
    /// Requests permission to access a file if needed
    /// - Parameter url: The URL to request access for
    /// - Returns: Boolean indicating if access was granted
    /// - Throws: FileAccessError if permission request fails
    @MainActor
    func requestPermission(for url: URL) async throws -> Bool {
        // Delegate to the FileSystemAccessManager
        return await accessManager.requestPermission(for: url)
    }
    
    /// Validates if a file URL is acceptable for processing
    /// - Parameter url: The URL to validate
    /// - Returns: Boolean indicating if the file is valid
    func isValidFile(_ url: URL) -> Bool {
        // Delegate to the FileSystemAccessManager
        return accessManager.isValidFile(url)
    }
    
    /// Validates a file URL and provides detailed information
    /// - Parameter url: The URL to validate
    /// - Returns: A validation result with specific information
    func validateFile(_ url: URL) -> FileValidationResult {
        // Delegate to the FileSystemAccessManager
        return accessManager.validateFile(url)
    }
    
    /// Checks if the application has access permissions for a file
    /// - Parameter url: The URL to check permissions for
    /// - Returns: Boolean indicating if file is accessible
    func canAccessFile(_ url: URL) -> Bool {
        // Delegate to the FileSystemAccessManager
        return accessManager.canAccessFile(url)
    }
}

// MARK: - File Drop Support

/// Extension to support file drop operations in SwiftUI
struct FileDropDelegate: DropDelegate {
    /// The FileSelectionService to handle dropped files
    private let fileService: FileSelectionService
    
    /// Callback for successful file selection
    private let onFileSelected: (FileReference) -> Void
    
    /// Callback for error handling
    private let onError: (FileAccessError) -> Void
    
    /// Callback for drop enter
    private let onDropEnter: () -> Void
    
    /// Callback for drop exit
    private let onDropExit: () -> Void
    
    init(
        fileService: FileSelectionService,
        onFileSelected: @escaping (FileReference) -> Void,
        onError: @escaping (FileAccessError) -> Void,
        onDropEnter: @escaping () -> Void = {},
        onDropExit: @escaping () -> Void = {}
    ) {
        self.fileService = fileService
        self.onFileSelected = onFileSelected
        self.onError = onError
        self.onDropEnter = onDropEnter
        self.onDropExit = onDropExit
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        // Check if the drop contains file URLs
        return info.hasItemsConforming(to: [UTType.fileURL.identifier])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        // Extract the file URLs from the drop
        guard let itemProvider = info.itemProviders(for: [UTType.fileURL.identifier]).first else {
            DispatchQueue.main.async {
                self.onError(FileAccessError.fileNotFound(nil, "No valid file in drop data"))
            }
            return false
        }
        
        // Load the item asynchronously
        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { (urlData, error) in
            guard error == nil else {
                let fileError = FileAccessError.from(error: error!, url: nil)
                DispatchQueue.main.async {
                    self.onError(fileError)
                }
                return
            }
            
            // Process the URL data
            if let urlData = urlData as? Data,
               let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                
                // Handle the file on the main thread
                DispatchQueue.main.async {
                    do {
                        // Validate the file with detailed error information
                        let validationResult = self.fileService.validateFile(url)
                        switch validationResult {
                        case .valid:
                            break // Continue processing
                        case .invalid(let error):
                            self.onError(error)
                            return
                        }
                        
                        // Check if we have access to the file
                        if !self.fileService.canAccessFile(url) {
                            self.onError(FileAccessError.permissionDenied(url, "Permission to access the dropped file was denied"))
                            return
                        }
                        
                        let fileReference = try self.fileService.handleFileDropped(url: url)
                        self.onFileSelected(fileReference)
                    } catch {
                        if let fileError = error as? FileAccessError {
                            self.onError(fileError)
                        } else {
                            self.onError(FileAccessError.from(error: error, url: url))
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.onError(FileAccessError.readError(nil, NSError(domain: "com.example.FileMetaView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not process dropped file data"])))
                }
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Provide visual feedback when drag enters the drop zone
        onDropEnter()
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Check if the item is a supported file type (if possible)
        return DropProposal(operation: .copy)
    }
    
    func dropExited(info: DropInfo) {
        // Provide visual feedback when drag exits the drop zone
        onDropExit()
    }
}
