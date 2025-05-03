import Foundation

/// Error type for file access and operations in FileMetaView
enum FileAccessError: Error, Identifiable, Equatable {
    // Implement Equatable for comparing errors
    static func == (lhs: FileAccessError, rhs: FileAccessError) -> Bool {
        return lhs.id == rhs.id
    }
    // MARK: - Error Cases
    
    /// Permission to access the file was denied
    case permissionDenied(URL?, String?)
    
    /// The file could not be found
    case fileNotFound(URL?, String?)
    
    /// The file type is not supported by the application
    case unsupportedFileType(URL?, String?)
    
    /// An error occurred while reading the file
    case readError(URL?, Error?)
    
    /// An error occurred while processing file metadata
    case metadataExtractionFailed(URL?, Error?)
    
    /// The requested operation was cancelled by the user
    case operationCancelled(String?)
    
    /// The file is too large to process
    case fileTooLarge(URL?, Int64)
    
    /// The operation timed out
    case timeout(URL?, String?)
    
    /// Access to the file was revoked
    case accessRevoked(URL?)
    
    /// Application lacks necessary permissions
    case insufficientPermissions(String?)
    
    /// Generic error for unexpected conditions
    case unknown(Error?)
    
    // MARK: - Identifiable Conformance
    
    /// Unique identifier for Identifiable conformance
    public var id: String {
        switch self {
        case .permissionDenied(let url, _):
            return "permissionDenied_\(url?.absoluteString ?? "unknown")"
        case .fileNotFound(let url, _):
            return "fileNotFound_\(url?.absoluteString ?? "unknown")"
        case .unsupportedFileType(let url, _):
            return "unsupportedFileType_\(url?.absoluteString ?? "unknown")"
        case .readError(let url, _):
            return "readError_\(url?.absoluteString ?? "unknown")"
        case .metadataExtractionFailed(let url, _):
            return "metadataExtractionFailed_\(url?.absoluteString ?? "unknown")"
        case .operationCancelled:
            return "operationCancelled"
        case .fileTooLarge(let url, _):
            return "fileTooLarge_\(url?.absoluteString ?? "unknown")"
        case .timeout(let url, _):
            return "timeout_\(url?.absoluteString ?? "unknown")"
        case .accessRevoked(let url):
            return "accessRevoked_\(url?.absoluteString ?? "unknown")"
        case .insufficientPermissions:
            return "insufficientPermissions"
        case .unknown:
            return "unknown"
        }
    }
}

// MARK: - LocalizedError Conformance

extension FileAccessError: LocalizedError {
    /// User-friendly error description
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let url, let message):
            if let message = message {
                return message
            }
            if let url = url {
                return "Permission denied for file: \(url.lastPathComponent)"
            }
            return "Permission denied for file access"
            
        case .fileNotFound(let url, let message):
            if let message = message {
                return message
            }
            if let url = url {
                return "File not found: \(url.lastPathComponent)"
            }
            return "File not found"
            
        case .unsupportedFileType(let url, let message):
            if let message = message {
                return message
            }
            if let url = url {
                return "Unsupported file type: \(url.pathExtension)"
            }
            return "Unsupported file type"
            
        case .readError(let url, let error):
            if let url = url {
                return "Error reading file: \(url.lastPathComponent) - \(error?.localizedDescription ?? "Unknown error")"
            }
            return "Error reading file: \(error?.localizedDescription ?? "Unknown error")"
            
        case .metadataExtractionFailed(let url, let error):
            if let url = url {
                return "Failed to extract metadata from \(url.lastPathComponent): \(error?.localizedDescription ?? "Unknown error")"
            }
            return "Failed to extract metadata: \(error?.localizedDescription ?? "Unknown error")"
            
        case .operationCancelled(let message):
            return message ?? "Operation cancelled by user"
            
        case .fileTooLarge(let url, let size):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            let sizeString = formatter.string(fromByteCount: size)
            
            if let url = url {
                return "File is too large to process: \(url.lastPathComponent) (\(sizeString))"
            }
            return "File is too large to process (\(sizeString))"
            
        case .timeout(let url, let message):
            if let message = message {
                return message
            }
            if let url = url {
                return "Operation timed out for file: \(url.lastPathComponent)"
            }
            return "Operation timed out"
            
        case .accessRevoked(let url):
            if let url = url {
                return "Access to file was revoked: \(url.lastPathComponent)"
            }
            return "Access to file was revoked"
            
        case .insufficientPermissions(let permission):
            if let permission = permission {
                return "Application lacks necessary permissions: \(permission)"
            }
            return "Application lacks necessary permissions"
            
        case .unknown(let error):
            return "An unexpected error occurred: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
    
    /// Enhanced recovery suggestions with more user-friendly guidance
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Click 'Request Permission' to grant FileMetaView access to this file. macOS security requires your explicit permission for apps to access your files. You can also try selecting the file again or moving it to a more accessible location like your Documents folder."
            
        case .fileNotFound:
            return "The file may have been moved, renamed, or deleted. Try selecting the file again or check if it still exists at the original location. If you recently moved the file, you might need to locate it in its new position."
            
        case .unsupportedFileType:
            return "FileMetaView can extract metadata from most common file types including images, documents, audio and video. You can click 'Show Supported Types' to see the full list, or try the 'Basic Extraction' option which might work with limited results."
            
        case .readError:
            return "There was a problem reading the file data. Make sure the file isn't corrupted, locked by another application, or on a disconnected drive. Try closing other applications that might be using this file and select it again."
            
        case .metadataExtractionFailed:
            return "FileMetaView couldn't extract metadata from this file. The file might be corrupted, password-protected, or using an uncommon format variation. Try selecting a different file or checking if the file opens properly in its native application."
            
        case .operationCancelled:
            return "The operation was cancelled. You can try again by selecting a file or dropping one onto the drop zone."
            
        case .fileTooLarge(_, let size):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            let sizeString = formatter.string(fromByteCount: size)
            return "This file (\(sizeString)) exceeds FileMetaView's processing limit. For optimal performance, try with files under 100MB. Very large files may cause the application to become unresponsive or run out of memory."
            
        case .timeout:
            return "The metadata extraction took too long and was stopped. This can happen with complex files or when your system is under heavy load. Try again when your computer is less busy, or use a smaller or simpler file."
            
        case .accessRevoked:
            return "Your previously granted access to this file has expired or been revoked. This commonly happens after system restarts or when files are moved. Click 'Restore Access' to regrant permission for this file."
            
        case .insufficientPermissions:
            return "FileMetaView needs additional system permissions to access this file. Click 'Open Security Settings' and ensure FileMetaView has Full Disk Access or access to the specific folders containing your files."
            
        case .unknown:
            return "An unexpected error occurred. Try restarting the application, selecting a different file, or if the problem persists, check for application updates. Most transient errors can be resolved by restarting the application."
        }
    }
    
    /// The domain of the error
    public var failureReason: String? {
        switch self {
        case .permissionDenied:
            return "The system has denied access to the requested resource"
            
        case .fileNotFound:
            return "The requested file does not exist or has been moved"
            
        case .unsupportedFileType:
            return "The file type is not supported by this application"
            
        case .readError:
            return "Failed to read data from the file"
            
        case .metadataExtractionFailed:
            return "Failed to extract or process metadata from the file"
            
        case .operationCancelled:
            return "The operation was cancelled"
            
        case .fileTooLarge:
            return "The file exceeds the maximum size limit"
            
        case .timeout:
            return "The operation took too long to complete"
            
        case .accessRevoked:
            return "Previously granted access has been revoked"
            
        case .insufficientPermissions:
            return "The application does not have required system permissions"
            
        case .unknown:
            return "An unexpected error condition occurred"
        }
    }
}

// MARK: - Helper Methods

extension FileAccessError {
    /// Factory method to create appropriate error from a system error
    /// - Parameters:
    ///   - error: The original system error
    ///   - url: Optional URL related to the error
    /// - Returns: The appropriate FileAccessError
    static func from(error: Error, url: URL? = nil) -> FileAccessError {
        let nsError = error as NSError
        
        // Common error codes that might indicate specific issues
        switch nsError.domain {
        case NSCocoaErrorDomain:
            switch nsError.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .fileNotFound(url, error.localizedDescription)
                
            case NSFileReadInvalidFileNameError:
                return .fileNotFound(url, "Invalid file name")
                
            case NSFileReadUnknownError:
                return .readError(url, error)
                
            case NSFileReadNoPermissionError:
                return .permissionDenied(url, error.localizedDescription)
                
            case NSFileReadTooLargeError:
                let fileSize = (error as NSError).userInfo[NSFilePathErrorKey] as? Int64 ?? 0
                return .fileTooLarge(url, fileSize)
                
            case NSUserCancelledError:
                return .operationCancelled("Operation cancelled by user")
                
            default:
                return .readError(url, error)
            }
            
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout(url, error.localizedDescription)
                
            case NSURLErrorCancelled:
                return .operationCancelled("Operation cancelled by user")
                
            case NSURLErrorNoPermissionsToReadFile:
                return .permissionDenied(url, error.localizedDescription)
                
            default:
                return .readError(url, error)
            }
            
        default:
            return .unknown(error)
        }
    }
}
