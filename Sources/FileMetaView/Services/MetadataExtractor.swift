import Foundation
import UniformTypeIdentifiers

/// Protocol defining the interface for file metadata extraction
protocol MetadataExtractor {
    /// Extracts metadata from a file
    /// - Parameter file: The file reference to extract metadata from
    /// - Returns: An array of metadata items
    /// - Throws: FileAccessError if extraction fails
    /// - Note: Implementations should check for Task.isCancelled regularly and throw OperationCancelledError when detected
    func extractMetadata(from file: FileReference) async throws -> [MetadataItem]
    
    /// Checks if this extractor can handle a specific file type
    /// - Parameters:
    ///   - fileType: The UTI string of the file
    ///   - fileExtension: Optional file extension as fallback
    /// - Returns: Boolean indicating if this extractor can handle the file type
    func canHandle(fileType: String, fileExtension: String?) -> Bool
    
    /// Maximum number of metadata items to extract
    /// - Returns: The maximum number of items this extractor will return
    func maximumItems() -> Int
    
    /// Priority of this extractor relative to others
    /// - Returns: Priority value (higher values indicate higher priority)
    func priority() -> Int
    
    /// Performance impact rating of this extractor (1-10)
    /// - Returns: Rating where higher values indicate more resource-intensive processing
    func performanceImpact() -> Int
    
    /// Recommended file size limit for this extractor
    /// - Returns: Maximum recommended file size in bytes, or nil for no limit
    func recommendedFileSizeLimit() -> Int64?
    
    /// Categories of metadata this extractor can provide
    /// - Returns: Array of metadata categories this extractor handles
    func providedCategories() -> [MetadataCategory]
    
    /// Name of this extractor for identification
    /// - Returns: String identifier for this extractor type
    func extractorName() -> String
    
    /// Description of the types of metadata this extractor provides
    /// - Returns: Human-readable description
    func extractorDescription() -> String
}

// MARK: - Default Implementations

extension MetadataExtractor {
    /// Default maximum number of metadata items (30)
    /// This enforces the application requirement to show a maximum of 30 fields
    func maximumItems() -> Int {
        return 30 // Hard limit for UI display purposes
    }
    
    /// Default priority (1)
    func priority() -> Int {
        return 1
    }
    
    /// Default performance impact (5 - medium)
    func performanceImpact() -> Int {
        return 5
    }
    
    /// Default file size limit recommendation (500MB)
    func recommendedFileSizeLimit() -> Int64? {
        return 500 * 1024 * 1024
    }
    
    /// Default extractor name based on type
    func extractorName() -> String {
        return String(describing: type(of: self))
    }
    
    /// Default supported categories
    func providedCategories() -> [MetadataCategory] {
        return [.basic]
    }
    
    /// Default description
    func extractorDescription() -> String {
        return "Extracts metadata from files"
    }
    
    /// Utility to limit the number of metadata items returned
    /// - Parameter items: The original array of metadata items
    /// - Returns: Array limited to the maximum number of items
    func limitItems(_ items: [MetadataItem]) -> [MetadataItem] {
        let max = maximumItems()
        guard items.count > max else { return items }
        
        // Sort items by priority
        // Priority: Basic category first, then by category sort order
        let sortedItems = items.sorted { (item1, item2) -> Bool in
            // First prioritize items in the basic category
            if item1.category == .basic && item2.category != .basic {
                return true
            }
            if item1.category != .basic && item2.category == .basic {
                return false
            }
            
            // Then sort by category sort order
            if item1.category.sortOrder != item2.category.sortOrder {
                return item1.category.sortOrder < item2.category.sortOrder
            }
            
            // Finally sort alphabetically by display name
            return item1.displayName < item2.displayName
        }
        
        // Return the limited set of items
        return Array(sortedItems.prefix(max))
    }
    
    /// Helper to check UTI conformance
    /// - Parameters:
    ///   - fileType: The UTI string to check
    ///   - conformsTo: A UTI string that fileType should conform to
    /// - Returns: Boolean indicating if fileType conforms to conformsTo
    func utiConforms(_ fileType: String, to conformsTo: String) -> Bool {
        guard let type = UTType(fileType), let standard = UTType(conformsTo) else {
            return false
        }
        return type.conforms(to: standard)
    }
    
    /// Helper to determine if the file type is a specific type based on UTI or extension
    /// - Parameters:
    ///   - fileType: The UTI string to check
    ///   - fileExtension: Optional file extension as fallback
    ///   - utiTypes: Array of UTI strings to check conformance against
    ///   - extensions: Array of file extensions to check
    /// - Returns: Boolean indicating if the file matches any of the criteria
    func isFileType(_ fileType: String, fileExtension: String?, utiTypes: [String], extensions: [String]) -> Bool {
        // First check UTI conformance
        for utiType in utiTypes {
            if utiConforms(fileType, to: utiType) {
                return true
            }
        }
        
        // Then check for exact UTI match
        if utiTypes.contains(fileType) {
            return true
        }
        
        // Finally check extensions if UTI checks failed
        if let ext = fileExtension?.lowercased(), extensions.contains(ext) {
            return true
        }
        
        return false
    }
    
    /// Helper to create metadata items from dictionary
    /// - Parameters:
    ///   - dict: Dictionary of metadata key-value pairs
    ///   - categoryMapper: Optional function to map keys to categories
    /// - Returns: Array of metadata items
    func createMetadataItems(from dict: [String: Any], categoryMapper: ((String) -> MetadataCategory)? = nil) -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        for (key, value) in dict {
            // Skip nil values
            if value is NSNull { continue }
            
            // Set current key in thread dictionary for type detection context
            Thread.current.threadDictionary["currentMetadataKey"] = key
            
            // Determine value type
            let valueType = MetadataValueType.detectType(of: value, key: key)
            
            // Determine category
            let category: MetadataCategory
            if let mapper = categoryMapper {
                category = mapper(key)
            } else {
                category = MetadataCategory.categorize(key: key)
            }
            
            // Create metadata item
            let item = MetadataItem(key: key, value: value, category: category, valueType: valueType)
            items.append(item)
        }
        
        // Clear the thread dictionary
        Thread.current.threadDictionary.removeObject(forKey: "currentMetadataKey")
        
        return items
    }
    
    /// Helper to handle extraction errors
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - file: The file reference involved
    ///   - context: Optional context message
    /// - Returns: A FileAccessError appropriate for the situation
    func handleExtractionError(_ error: Error, file: FileReference, context: String = "") -> FileAccessError {
        // If it's already a FileAccessError, return it
        if let fileError = error as? FileAccessError {
            return fileError
        }
        
        // Check for common error types
        let nsError = error as NSError
        
        // Permission errors
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return .permissionDenied(file.url, "\(context): Permission denied")
        }
        
        // File not found
        if nsError.domain == NSCocoaErrorDomain && 
           (nsError.code == NSFileNoSuchFileError || nsError.code == NSFileReadNoSuchFileError) {
            return .fileNotFound(file.url, "\(context): File not found")
        }
        
        // Unsupported type
        if nsError.domain == "com.example.FileMetaView.metadata" && nsError.code == 1001 {
            return .unsupportedFileType(file.url, "\(context): Unsupported file type")
        }
        
        // Read errors
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadUnknownError {
            return .readError(file.url, error)
        }
        
        // Default to metadata extraction error
        return .metadataExtractionFailed(file.url, error)
    }
}

/// A result type to hold metadata extraction results
struct MetadataExtractionResult {
    /// The extracted metadata items
    let items: [MetadataItem]
    
    /// The extractor that produced these items
    let extractor: MetadataExtractor
    
    /// Any warnings that occurred during extraction
    let warnings: [String]
    
    /// Performance metrics for the extraction operation
    let metrics: ExtractionMetrics?
    
    /// Initialize a successful extraction result
    /// - Parameters:
    ///   - items: The extracted metadata items
    ///   - extractor: The extractor that produced these items
    ///   - warnings: Any warnings that occurred
    ///   - metrics: Optional performance metrics
    init(items: [MetadataItem], extractor: MetadataExtractor, warnings: [String] = [], metrics: ExtractionMetrics? = nil) {
        self.items = items
        self.extractor = extractor
        self.warnings = warnings
        self.metrics = metrics
    }
}

/// Performance metrics for metadata extraction
struct ExtractionMetrics {
    /// Start time of the extraction
    let startTime: Date
    
    /// End time of the extraction
    let endTime: Date
    
    /// Total duration in seconds
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Number of metadata items extracted
    let itemCount: Int
    
    /// Size of the file processed in bytes
    let fileSize: Int64
    
    /// Whether the operation was memory-intensive
    let memoryIntensive: Bool
    
    /// Initialize with start and end times
    /// - Parameters:
    ///   - startTime: When extraction began
    ///   - endTime: When extraction completed
    ///   - itemCount: Number of extracted items
    ///   - fileSize: Size of processed file
    ///   - memoryIntensive: Whether operation was memory-intensive
    init(startTime: Date, endTime: Date, itemCount: Int, fileSize: Int64, memoryIntensive: Bool = false) {
        self.startTime = startTime
        self.endTime = endTime
        self.itemCount = itemCount
        self.fileSize = fileSize
        self.memoryIntensive = memoryIntensive
    }
    
    /// Helper to create metrics from a start time and file size
    /// - Parameters:
    ///   - startTime: When extraction began
    ///   - items: The extracted items
    ///   - fileSize: Size of the processed file
    ///   - memoryIntensive: Whether the operation was memory-intensive
    /// - Returns: A new ExtractionMetrics instance
    static func create(from startTime: Date, items: [MetadataItem], fileSize: Int64, memoryIntensive: Bool = false) -> ExtractionMetrics {
        return ExtractionMetrics(
            startTime: startTime,
            endTime: Date(),
            itemCount: items.count,
            fileSize: fileSize,
            memoryIntensive: memoryIntensive
        )
    }
}

/// Errors specific to metadata extraction
enum MetadataExtractionError: Error {
    /// Error indicating this extractor cannot handle the file type
    case unsupportedFileType(String)
    
    /// Error indicating the metadata could not be parsed
    case metadataParsingFailed(String)
    
    /// Error indicating the extractor was unable to access required resources
    case resourceAccessFailed(String)
    
    /// Error indicating the file is corrupted or malformed
    case malformedFile(String)
    
    /// Error indicating the file is too large for this extractor
    case fileTooLargeForExtractor(Int64, Int64)
    
    /// Error indicating the extraction process was too resource-intensive
    case processingTooIntensive(String)
    
    /// Error indicating the extraction timed out
    case extractionTimeout(TimeInterval)
    
    /// Error indicating the operation was cancelled
    case operationCancelled(String)
}

/// Extension to add cancellation checks for MetadataExtractor implementations
extension MetadataExtractor {
    /// Check if the current task has been cancelled and throw if it has
    /// - Throws: MetadataExtractionError.operationCancelled if task is cancelled
    func checkCancellation() throws {
        if Task.isCancelled {
            throw MetadataExtractionError.operationCancelled("Metadata extraction was cancelled")
        }
    }
    
    /// Check if the current task has been cancelled at regular intervals during extraction
    /// - Parameter operation: The operation to perform between cancellation checks
    /// - Throws: Rethrows any error from the operation, or MetadataExtractionError.operationCancelled if task is cancelled
    func withCancellationChecks<T>(_ operation: () async throws -> T) async throws -> T {
        // Check for cancellation before starting
        try checkCancellation()
        
        // Perform the operation
        let result = try await operation()
        
        // Check for cancellation after completing
        try checkCancellation()
        
        return result
    }
}
