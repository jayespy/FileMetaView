import Foundation
import UniformTypeIdentifiers
import PDFKit
import CoreServices
import CoreSpotlight
import os.log

/// A metadata extractor specialized for document files (PDF, DOC, TXT, etc.)
class DocumentMetadataExtractor: MetadataExtractor {
    /// Logger for this extractor
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "DocumentMetadataExtractor")
    
    /// Document UTI types this extractor can handle
    private let supportedDocumentTypes = [
        UTType.pdf.identifier,
        UTType.plainText.identifier,
        UTType.rtf.identifier,
        UTType.rtfd.identifier,
        UTType.html.identifier,
        "com.microsoft.word.doc",         // DOC
        "org.openxmlformats.wordprocessingml.document", // DOCX
        "com.apple.iwork.pages.pages",    // Pages
        "public.epub",                    // EPUB
        "com.adobe.postscript",           // PS
        "org.oasis-open.opendocument.text", // ODT
        "public.markdown",                // Markdown
    ]
    
    /// Document file extensions this extractor can handle
    private let supportedDocumentExtensions = [
        "pdf", "txt", "text", "rtf", "rtfd", "html", "htm", "doc", "docx", 
        "pages", "epub", "ps", "odt", "md", "markdown", "tex"
    ]
    
    /// Initialize a new DocumentMetadataExtractor
    init() {}
    
    /// Extract metadata from a document file
    /// - Parameter file: The file reference to extract metadata from
    /// - Returns: An array of metadata items
    /// - Throws: FileAccessError if extraction fails
    func extractMetadata(from file: FileReference) async throws -> [MetadataItem] {
        logger.info("Extracting document metadata for file: \(file.url.lastPathComponent)")
        
        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: file.url.path) else {
            logger.error("File does not exist: \(file.url.path)")
            throw FileAccessError.fileNotFound(file.url, "File does not exist")
        }
        
        guard FileManager.default.isReadableFile(atPath: file.url.path) else {
            logger.error("File is not readable: \(file.url.path)")
            throw FileAccessError.permissionDenied(file.url, "File is not readable")
        }
        
        var items: [MetadataItem] = []
        
        do {
            // Extract basic document properties
            let basicItems = try extractBasicDocumentProperties(file)
            items.append(contentsOf: basicItems)
            
            // Extract Spotlight/MDItem metadata
            let mdItems = try extractMDItemMetadata(file)
            items.append(contentsOf: mdItems)
            
            // Extract format-specific metadata
            if file.fileExtension.lowercased() == "pdf" {
                let pdfItems = try extractPDFMetadata(file)
                items.append(contentsOf: pdfItems)
            }
            
            // Limit the number of items and return
            return limitItems(items)
        } catch let error as MetadataExtractionError {
            logger.error("Error extracting document metadata: \(error)")
            switch error {
            case .unsupportedFileType(let message):
                throw FileAccessError.unsupportedFileType(file.url, message)
            case .operationCancelled(let message):
                throw FileAccessError.operationCancelled(message)
            case .metadataParsingFailed(let message):
                throw FileAccessError.metadataExtractionFailed(file.url, NSError(domain: "com.example.FileMetaView.metadata", code: 1002, userInfo: [NSLocalizedDescriptionKey: message]))
            case .resourceAccessFailed(let message):
                throw FileAccessError.readError(file.url, NSError(domain: "com.example.FileMetaView.metadata", code: 1003, userInfo: [NSLocalizedDescriptionKey: message]))
            case .malformedFile(let message):
                throw FileAccessError.readError(file.url, NSError(domain: "com.example.FileMetaView.metadata", code: 1004, userInfo: [NSLocalizedDescriptionKey: message]))
            case .fileTooLargeForExtractor(let fileSize, _):
                throw FileAccessError.fileTooLarge(file.url, fileSize)
            case .processingTooIntensive(let message):
                throw FileAccessError.metadataExtractionFailed(file.url, NSError(domain: "com.example.FileMetaView.metadata", code: 1005, userInfo: [NSLocalizedDescriptionKey: message]))
            case .extractionTimeout(let seconds):
                throw FileAccessError.timeout(file.url, "Document metadata extraction timed out after \(Int(seconds)) seconds")
            }
        } catch {
            logger.error("Error extracting document metadata: \(error.localizedDescription)")
            throw handleExtractionError(error, file: file, context: "Document metadata extraction")
        }
    }
    
    /// Check if this extractor can handle a specific file type
    /// - Parameters:
    ///   - fileType: The UTI string of the file
    ///   - fileExtension: Optional file extension as fallback
    /// - Returns: Boolean indicating if this extractor can handle the file type
    func canHandle(fileType: String, fileExtension: String?) -> Bool {
        // Check by UTI conformance to document type
        if utiConforms(fileType, to: UTType.text.identifier) ||
           utiConforms(fileType, to: UTType.pdf.identifier) {
            return true
        }
        
        // Check by specific UTI types
        if supportedDocumentTypes.contains(fileType) {
            return true
        }
        
        // Check by extension if UTI checks failed
        if let ext = fileExtension?.lowercased(), supportedDocumentExtensions.contains(ext) {
            return true
        }
        
        return false
    }
    
    /// Name of this extractor for identification
    /// - Returns: String identifier for this extractor type
    func extractorName() -> String {
        return "Document Metadata Extractor"
    }
    
    /// Description of the types of metadata this extractor provides
    /// - Returns: Human-readable description
    func extractorDescription() -> String {
        return "Extracts metadata from document files including author information, content details, and file properties"
    }
    
    /// Categories of metadata this extractor can provide
    /// - Returns: Array of metadata categories this extractor handles
    func providedCategories() -> [MetadataCategory] {
        return [.document]
    }
    
    /// Priority of this extractor relative to others
    /// - Returns: Priority value (higher values indicate higher priority)
    func priority() -> Int {
        // Document metadata extractor has high priority for document files
        return 8
    }
    
    /// Performance impact rating of this extractor (1-10)
    /// - Returns: Rating where higher values indicate more resource-intensive processing
    func performanceImpact() -> Int {
        // Document metadata extraction can be resource-intensive
        return 7
    }
    
    /// Recommended file size limit for this extractor
    /// - Returns: Maximum recommended file size in bytes, or nil for no limit
    func recommendedFileSizeLimit() -> Int64? {
        // For document files, reasonable limit is 150MB
        return 150 * 1024 * 1024
    }
    
    // MARK: - Private Methods
    
    /// Extract basic document properties (file size, dates, etc.)
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for basic document properties
    private func extractBasicDocumentProperties(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Add file name
        items.append(MetadataItem(
            key: "fileName",
            value: file.name,
            category: .document,
            valueType: .string
        ))
        
        // Add file extension
        items.append(MetadataItem(
            key: "fileExtension",
            value: file.fileExtension,
            category: .document,
            valueType: .string
        ))
        
        // Add file type description
        items.append(MetadataItem(
            key: "fileType",
            value: file.typeDescription,
            category: .document,
            valueType: .string
        ))
        
        // Add file size
        items.append(MetadataItem(
            key: "fileSize",
            value: file.size,
            category: .document,
            valueType: .fileSize
        ))
        
        // Add creation and modification dates
        if let creationDate = file.creationDate {
            items.append(MetadataItem(
                key: "creationDate",
                value: creationDate,
                category: .document,
                valueType: .date
            ))
        }
        
        if let modificationDate = file.modificationDate {
            items.append(MetadataItem(
                key: "modificationDate",
                value: modificationDate,
                category: .document,
                valueType: .date
            ))
        }
        
        // Try to get character count and other text properties for text files
        if UTType(file.type)?.conforms(to: UTType.text) == true {
            do {
                let fileContents = try String(contentsOf: file.url, encoding: .utf8)
                
                // Character count
                let characterCount = fileContents.count
                items.append(MetadataItem(
                    key: "characterCount",
                    value: characterCount,
                    category: .document,
                    valueType: .number
                ))
                
                // Word count (approximate)
                let words = fileContents.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                items.append(MetadataItem(
                    key: "wordCount",
                    value: words.count,
                    category: .document,
                    valueType: .number
                ))
                
                // Line count
                let lines = fileContents.components(separatedBy: .newlines)
                items.append(MetadataItem(
                    key: "lineCount",
                    value: lines.count,
                    category: .document,
                    valueType: .number
                ))
            } catch {
                // Just log the error but don't fail - this is optional metadata
                logger.warning("Could not read text content: \(error.localizedDescription)")
            }
        }
        
        return items
    }
    
    /// Extract metadata using MDItem (Spotlight) API
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items from MDItem
    private func extractMDItemMetadata(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Create an MDItem for the file
        guard let mdItem = MDItemCreate(nil, file.url.path as CFString) else {
            // If MDItem creation fails, it's not necessarily an error
            // Some files might not have Spotlight metadata
            return items
        }
        
        // Define the attributes to extract
        let attributes: [String] = [
            // Common document attributes
            "kMDItemTitle",
            "kMDItemAuthors",
            "kMDItemDescription",
            "kMDItemCopyright",
            "kMDItemKeywords",
            "kMDItemSubject",
            "kMDItemLanguages",
            "kMDItemCreator",
            "kMDItemPublishers",
            "kMDItemComment",
            "kMDItemVersion",
            "kMDItemTextContent",
            
            // Document specific attributes
            "kMDItemNumberOfPages",
            "kMDItemSecurityMethod",
            "kMDItemContentType",
            "kMDItemContentTypeTree",
            "kMDItemKind",
            "kMDItemFonts",
            "kMDItemEncodingApplications",
            
            // Creation and modification
            "kMDItemContentCreationDate",
            "kMDItemContentModificationDate",
            "kMDItemLastUsedDate",
            
            // Content stats
            "kMDItemWhereFroms"
        ]
        
        // Convert attribute array to CFArray
        let attributesCFArray = attributes as CFArray
        
        // Get attributes from MDItem
        if let attrDict = MDItemCopyAttributes(mdItem, attributesCFArray) as? [String: Any] {
            // Create metadata items from dictionary
            for (key, value) in attrDict {
                if value is NSNull { continue }
                
                // Format the key for display
                let formattedKey = key
                    .replacingOccurrences(of: "kMDItem", with: "")
                    .replacingOccurrences(of: "MD", with: "")
                
                // Determine category
                let category = MetadataCategory.document
                
                // Determine value type
                let valueType: MetadataValueType
                
                // Check key for determining appropriate value type
                let keyLower = key.lowercased()
                if keyLower.contains("date") {
                    valueType = .date
                } else if keyLower.contains("count") || keyLower.contains("number") || keyLower.contains("pages") {
                    valueType = .number
                } else if keyLower.contains("bool") || keyLower.contains("printable") || keyLower.contains("allows") {
                    valueType = .boolean
                } else if keyLower.contains("url") || keyLower.contains("wherefrom") {
                    valueType = .url
                } else {
                    valueType = MetadataValueType.detectType(of: value, key: key)
                }
                
                // Special handling for arrays
                if let arrayValue = value as? [Any], !arrayValue.isEmpty {
                    // For arrays with a single item, just use that item
                    if arrayValue.count == 1, let singleValue = arrayValue.first {
                        items.append(MetadataItem(
                            key: formattedKey,
                            value: singleValue,
                            category: category,
                            valueType: valueType
                        ))
                    } else {
                        // For multi-item arrays, include both the array and a joined string
                        items.append(MetadataItem(
                            key: formattedKey,
                            value: arrayValue,
                            category: category,
                            valueType: .array
                        ))
                        
                        // Add a joined string version for display
                        let joinedValue = arrayValue.map { String(describing: $0) }.joined(separator: ", ")
                        items.append(MetadataItem(
                            key: formattedKey + "Joined",
                            value: joinedValue,
                            category: category,
                            valueType: .string
                        ))
                    }
                } else {
                    // Regular single value
                    items.append(MetadataItem(
                        key: formattedKey,
                        value: value,
                        category: category,
                        valueType: valueType
                    ))
                }
            }
        }
        
        return items
    }
    
    /// Extract PDF-specific metadata
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items from PDF document
    private func extractPDFMetadata(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Create a PDFDocument from the file
        guard let pdfDocument = PDFDocument(url: file.url) else {
            throw MetadataExtractionError.metadataParsingFailed("Could not create PDF document")
        }
        
        // Get page count
        let pageCount = pdfDocument.pageCount
        items.append(MetadataItem(
            key: "pageCount",
            value: pageCount,
            category: .document,
            valueType: .number
        ))
        
        // Check if the document is encrypted
        let isEncrypted = pdfDocument.isEncrypted
        items.append(MetadataItem(
            key: "isEncrypted",
            value: isEncrypted,
            category: .document,
            valueType: .boolean
        ))
        
        // Check if document allows printing
        let allowsPrinting = pdfDocument.allowsPrinting
        items.append(MetadataItem(
            key: "allowsPrinting",
            value: allowsPrinting,
            category: .document,
            valueType: .boolean
        ))
        
        // Check if document allows copying
        let allowsCopying = pdfDocument.allowsCopying
        items.append(MetadataItem(
            key: "allowsCopying",
            value: allowsCopying,
            category: .document,
            valueType: .boolean
        ))
        
        // Get document attributes
        if let documentAttributes = pdfDocument.documentAttributes {
            // Common PDF attributes to look for
            let pdfAttributeMap: [String: (String, MetadataValueType)] = [
                "Author": ("author", .string),
                "Title": ("title", .string),
                "Subject": ("subject", .string),
                "Creator": ("creator", .string),
                "Producer": ("producer", .string),
                "CreationDate": ("creationDate", .date),
                "ModDate": ("modificationDate", .date),
                "Keywords": ("keywords", .string)
            ]
            
            // Extract all attributes
            for (key, value) in documentAttributes {
                if let keyString = key as? String {
                    var displayKey: String
                    var valueType: MetadataValueType
                    
                    // Check if it's a known attribute
                    if let (mappedKey, mappedType) = pdfAttributeMap[keyString] {
                        displayKey = mappedKey
                        valueType = mappedType
                    } else {
                        // Format the key for display
                        displayKey = keyString
                            .replacingOccurrences(of: "PDF", with: "")
                            .replacingOccurrences(of: "Document", with: "")
                            .replacingOccurrences(of: "Attribute", with: "")
                        
                        // Determine value type
                        valueType = MetadataValueType.detectType(of: value)
                    }
                    
                    items.append(MetadataItem(
                        key: displayKey,
                        value: value,
                        category: .document,
                        valueType: valueType
                    ))
                }
            }
        }
        
        // Get document permissions if available
        let permissionProperties = [
            "allowsPrinting": pdfDocument.allowsPrinting,
            "allowsCopying": pdfDocument.allowsCopying,
            "allowsDocumentChanges": pdfDocument.allowsDocumentChanges,
            "allowsDocumentAssembly": pdfDocument.allowsDocumentAssembly,
            "allowsContentAccessibility": pdfDocument.allowsContentAccessibility,
            "allowsCommenting": pdfDocument.allowsCommenting,
            "allowsFormFieldEntry": pdfDocument.allowsFormFieldEntry
        ]
        
        for (key, value) in permissionProperties {
            items.append(MetadataItem(
                key: key,
                value: value,
                category: .document,
                valueType: .boolean
            ))
        }
        
        // Try to get the outline (table of contents) item count
        if let outline = pdfDocument.outlineRoot, outline.numberOfChildren > 0 {
            items.append(MetadataItem(
                key: "outlineItemCount",
                value: outline.numberOfChildren,
                category: .document,
                valueType: .number
            ))
        }
        
        return items
    }
}
