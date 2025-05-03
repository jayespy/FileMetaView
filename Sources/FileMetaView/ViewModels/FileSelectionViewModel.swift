import SwiftUI
import Combine
import os.log

/// Temporary ViewModel for file selection until the full AppViewModel is implemented
class FileSelectionViewModel: ObservableObject {
    /// The file selection service
    let fileService: FileSelectionService
    
    /// Logger for error tracking
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "FileSelection")
    
    /// Published properties for UI binding
    @Published var selectedFile: FileReference?
    @Published var isLoading: Bool = false
    @Published var error: FileAccessError?
    
    /// Error display timeout in seconds
    private let errorDisplayTimeout: TimeInterval = 8.0
    
    /// Timer for auto-dismissing errors
    private var errorTimer: Timer?
    
    /// Initialize with dependencies
    /// - Parameter fileService: The file selection service to use
    init(fileService: FileSelectionService) {
        self.fileService = fileService
    }
    
    /// Clear any error
    func clearError() {
        error = nil
        cancelErrorTimer()
    }
    
    /// Clear the selected file
    func clearSelection() {
        selectedFile = nil
    }
    
    /// Select a file using the file selection service
    func selectFile() {
        Task {
            await MainActor.run {
                isLoading = true
                error = nil
                cancelErrorTimer()
            }
            
            do {
                let file = try await fileService.selectFile()
                
                await MainActor.run {
                    selectedFile = file
                    isLoading = false
                }
                
                logger.info("File selected successfully: \(file.url.lastPathComponent)")
            } catch {
                await handleError(error)
            }
        }
    }
    
    /// Handle file drop operations
    /// - Parameter url: The URL of the dropped file
    func handleFileDrop(url: URL) {
        Task {
            await MainActor.run {
                isLoading = true
                error = nil
                cancelErrorTimer()
            }
            
            do {
                let file = try fileService.handleFileDropped(url: url)
                
                await MainActor.run {
                    selectedFile = file
                    isLoading = false
                }
                
                logger.info("File dropped and processed successfully: \(file.url.lastPathComponent)")
            } catch {
                await handleError(error)
            }
        }
    }
    
    /// Handle errors from file operations
    /// - Parameter error: The error that occurred
    @MainActor
    private func handleError(_ error: Error) {
        isLoading = false
        
        // Determine the appropriate FileAccessError
        if let fileError = error as? FileAccessError {
            self.error = fileError
            logError(fileError)
        } else {
            let fileError = FileAccessError.from(error: error)
            self.error = fileError
            logError(fileError)
        }
        
        // Set up auto-dismiss timer for non-critical errors
        if case .operationCancelled = self.error {
            // Auto-dismiss cancellation errors quickly
            startErrorTimer(timeout: 3.0)
        } else {
            // Standard timeout for other errors
            startErrorTimer()
        }
    }
    
    /// Log error information
    /// - Parameter error: The error to log
    private func logError(_ error: FileAccessError) {
        // Customize the log message based on error type
        switch error {
        case .permissionDenied(let url, _):
            logger.error("Permission denied for file: \(url?.absoluteString ?? "unknown URL")")
            
        case .fileNotFound(let url, _):
            logger.error("File not found: \(url?.absoluteString ?? "unknown URL")")
            
        case .unsupportedFileType(let url, _):
            logger.error("Unsupported file type: \(url?.absoluteString ?? "unknown URL")")
            
        case .readError(let url, let underlyingError):
            logger.error("Error reading file: \(url?.absoluteString ?? "unknown URL"), error: \(String(describing: underlyingError))")
            
        case .metadataExtractionFailed(let url, let underlyingError):
            logger.error("Failed to extract metadata: \(url?.absoluteString ?? "unknown URL"), error: \(String(describing: underlyingError))")
            
        case .operationCancelled:
            logger.info("File selection operation cancelled by user")
            
        case .fileTooLarge(let url, let size):
            logger.error("File too large: \(url?.absoluteString ?? "unknown URL"), size: \(size) bytes")
            
        case .timeout(let url, _):
            logger.error("Operation timed out: \(url?.absoluteString ?? "unknown URL")")
            
        case .accessRevoked(let url):
            logger.error("Access revoked for file: \(url?.absoluteString ?? "unknown URL")")
            
        case .insufficientPermissions(let permission):
            logger.error("Insufficient permissions: \(permission ?? "unknown permission")")
            
        case .unknown(let underlyingError):
            logger.error("Unknown error: \(String(describing: underlyingError))")
        }
    }
    
    /// Start a timer to auto-dismiss error messages
    /// - Parameter timeout: Optional custom timeout duration
    private func startErrorTimer(timeout: TimeInterval? = nil) {
        cancelErrorTimer()
        
        let duration = timeout ?? errorDisplayTimeout
        errorTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.clearError()
            }
        }
    }
    
    /// Cancel any active error timer
    private func cancelErrorTimer() {
        errorTimer?.invalidate()
        errorTimer = nil
    }
    
    /// Check if a file is accessible and request permission if needed
    /// - Parameter url: The URL to check
    /// - Returns: Boolean indicating if file is accessible
    func ensureFileAccess(for url: URL) async -> Bool {
        if fileService.canAccessFile(url) {
            return true
        }
        
        // Try to request permission
        do {
            return try await fileService.requestPermission(for: url)
        } catch {
            await handleError(error)
            return false
        }
    }
}
