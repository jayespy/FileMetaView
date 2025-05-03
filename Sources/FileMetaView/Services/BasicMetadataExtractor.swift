import Foundation
import UniformTypeIdentifiers
import os.log

/// A metadata extractor for common file attributes
class BasicMetadataExtractor: MetadataExtractor {
    /// Logger for this extractor
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "BasicMetadataExtractor")
    
    /// Initialize a new BasicMetadataExtractor
    init() {}
    
    /// Extract basic metadata from a file using URLResourceValues
    /// - Parameter file: The file reference to extract metadata from
    /// - Returns: An array of metadata items
    /// - Throws: FileAccessError if extraction fails
    func extractMetadata(from file: FileReference) async throws -> [MetadataItem] {
        logger.info("Extracting basic metadata for file: \(file.url.lastPathComponent)")
        
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
            // Get basic file attributes using URLResourceValues
            let basicItems = try extractBasicAttributes(file)
            items.append(contentsOf: basicItems)
            
            // Get date-related attributes
            let dateItems = try extractDateAttributes(file)
            items.append(contentsOf: dateItems)
            
            // Get size-related attributes
            let sizeItems = try extractSizeAttributes(file)
            items.append(contentsOf: sizeItems)
            
            // Get type-related attributes
            let typeItems = try extractTypeAttributes(file)
            items.append(contentsOf: typeItems)
            
            // Get file system attributes from FileManager
            let fileSystemItems = try extractFileSystemAttributes(file)
            items.append(contentsOf: fileSystemItems)
            
            // Get permissions and ownership information
            let permissionItems = try extractPermissionAttributes(file)
            items.append(contentsOf: permissionItems)
            
            // Sort and limit the number of items to maximum 30 fields
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
            
            // Limit to maximumItems (default 30)
            return limitItems(sortedItems)
        } catch {
            logger.error("Error extracting metadata: \(error.localizedDescription)")
            throw handleExtractionError(error, file: file, context: "Basic metadata extraction")
        }
    }
    
    /// Check if this extractor can handle a specific file type
    /// - Parameters:
    ///   - fileType: The UTI string of the file
    ///   - fileExtension: Optional file extension as fallback
    /// - Returns: Boolean indicating if this extractor can handle the file type
    func canHandle(fileType: String, fileExtension: String?) -> Bool {
        // BasicMetadataExtractor can handle all file types
        return true
    }
    
    /// Name of this extractor for identification
    /// - Returns: String identifier for this extractor type
    func extractorName() -> String {
        return "Basic Metadata Extractor"
    }
    
    /// Description of the types of metadata this extractor provides
    /// - Returns: Human-readable description
    func extractorDescription() -> String {
        return "Extracts common file attributes such as size, dates, type, and permissions"
    }
    
    /// Categories of metadata this extractor can provide
    /// - Returns: Array of metadata categories this extractor handles
    func providedCategories() -> [MetadataCategory] {
        return [.basic, .filesystem, .permissions]
    }
    
    /// Priority of this extractor relative to others
    /// - Returns: Priority value (higher values indicate higher priority)
    func priority() -> Int {
        // Basic metadata extractor has highest priority as it's the most fundamental
        return 10
    }
    
    /// Performance impact rating of this extractor (1-10)
    /// - Returns: Rating where higher values indicate more resource-intensive processing
    func performanceImpact() -> Int {
        // Basic metadata extraction is very low on resources
        return 2
    }
    
    /// Recommended file size limit for this extractor
    /// - Returns: Maximum recommended file size in bytes, or nil for no limit
    func recommendedFileSizeLimit() -> Int64? {
        // Basic metadata extractor can handle files of any size
        return nil
    }
    
    // MARK: - Private Methods
    
    /// Extract basic file attributes using URLResourceValues
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for basic attributes
    private func extractBasicAttributes(_ file: FileReference) throws -> [MetadataItem] {
        // Define the resource keys we want to fetch
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .pathKey,
            .fileResourceTypeKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
            .addedToDirectoryDateKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isAliasFileKey,
            .isHiddenKey,
            .isPackageKey,
            .isApplicationKey,
            .isExcludedFromBackupKey,
            .fileResourceIdentifierKey,
            .volumeIdentifierKey,
            .typeIdentifierKey,
            .localizedNameKey,
            .localizedTypeDescriptionKey,
            .fileContentIdentifierKey,
            .hasHiddenExtensionKey,
            .isExecutableKey,
            .tagNamesKey,
            .isReadableKey,
            .isWritableKey
        ]
        
        // Fetch resource values
        let resourceValues = try file.url.resourceValues(forKeys: resourceKeys)
        
        // Convert to dictionary for easier processing
        let mirror = Mirror(reflecting: resourceValues)
        var resourceDict: [String: Any] = [:]
        
        for child in mirror.children {
            if let key = child.label, key != "allValues" {
                // Skip nil values
                if let optionalValue = Mirror(reflecting: child.value).displayStyle == .optional ? 
                   Mirror(reflecting: child.value).children.first?.value : child.value {
                    if !(optionalValue is NSNull) {
                        resourceDict[key] = optionalValue
                    }
                }
            }
        }
        
        // Add computed basic metadata that may not be in resource values
        resourceDict["fileExtension"] = file.fileExtension
        resourceDict["absolutePath"] = file.url.path
        resourceDict["parentDirectory"] = file.url.deletingLastPathComponent().path
        if let scheme = file.url.scheme {
            resourceDict["scheme"] = scheme
        }
        
        // Create metadata items
        var items: [MetadataItem] = []
        
        for (key, value) in resourceDict {
            // Determine category based on key
            let category: MetadataCategory
            if key.lowercased().contains("date") {
                category = .basic
            } else if key.lowercased().contains("permission") || key.lowercased().contains("readable") || 
                      key.lowercased().contains("writable") || key.lowercased().contains("executable") {
                category = .permissions
            } else {
                category = .basic
            }
            
            // Determine value type
            let valueType = MetadataValueType.detectType(of: value, key: key)
            
            // Create item
            let item = MetadataItem(key: key, value: value, category: category, valueType: valueType)
            items.append(item)
        }
        
        return items
    }
    
    /// Extract metadata related to file dates (creation, modification, access)
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for date attributes
    private func extractDateAttributes(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Define the date-related resource keys we want to fetch
        let resourceKeys: Set<URLResourceKey> = [
            .creationDateKey,
            .contentModificationDateKey,
            .contentAccessDateKey,
            .addedToDirectoryDateKey
        ]
        
        // Fetch resource values
        let resourceValues = try file.url.resourceValues(forKeys: resourceKeys)
        
        // Extract specific date values
        if let creationDate = resourceValues.creationDate {
            items.append(MetadataItem(
                key: "creationDate",
                value: creationDate,
                category: .basic,
                valueType: .date
            ))
        }
        
        if let modificationDate = resourceValues.contentModificationDate {
            items.append(MetadataItem(
                key: "modificationDate",
                value: modificationDate,
                category: .basic,
                valueType: .date
            ))
        }
        
        if let accessDate = resourceValues.contentAccessDate {
            items.append(MetadataItem(
                key: "accessDate",
                value: accessDate,
                category: .basic,
                valueType: .date
            ))
        }
        
        if let addedDate = resourceValues.addedToDirectoryDate {
            items.append(MetadataItem(
                key: "addedToDirectoryDate",
                value: addedDate,
                category: .basic,
                valueType: .date
            ))
        }
        
        // Add additional date information using FileManager attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
        
        // Check if there are any additional dates in the file attributes
        if let backupDate = attributes[FileAttributeKey.modificationDate] as? Date {
            items.append(MetadataItem(
                key: "backupDate",
                value: backupDate,
                category: .basic,
                valueType: .date
            ))
        }
        
        return items
    }
    
    /// Extract metadata related to file size and capacity
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for size attributes
    private func extractSizeAttributes(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Define the size-related resource keys
        let resourceKeys: Set<URLResourceKey> = [
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileSizeKey,
            .totalFileAllocatedSizeKey
        ]
        
        // Fetch resource values
        let resourceValues = try file.url.resourceValues(forKeys: resourceKeys)
        
        // Extract size values
        if let fileSize = resourceValues.fileSize {
            items.append(MetadataItem(
                key: "fileSize",
                value: Int64(fileSize),
                category: .basic,
                valueType: .fileSize
            ))
        }
        
        if let allocatedSize = resourceValues.fileAllocatedSize {
            items.append(MetadataItem(
                key: "fileAllocatedSize",
                value: Int64(allocatedSize),
                category: .filesystem,
                valueType: .fileSize
            ))
        }
        
        if let totalFileSize = resourceValues.totalFileSize {
            items.append(MetadataItem(
                key: "totalFileSize",
                value: Int64(totalFileSize),
                category: .filesystem,
                valueType: .fileSize
            ))
        }
        
        if let totalAllocatedSize = resourceValues.totalFileAllocatedSize {
            items.append(MetadataItem(
                key: "totalFileAllocatedSize",
                value: Int64(totalAllocatedSize),
                category: .filesystem,
                valueType: .fileSize
            ))
        }
        
        return items
    }
    
    /// Extract metadata related to file type and content
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for type attributes
    private func extractTypeAttributes(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Define the type-related resource keys
        let resourceKeys: Set<URLResourceKey> = [
            .typeIdentifierKey,
            .contentTypeKey,
            .localizedTypeDescriptionKey
        ]
        
        // Fetch resource values
        let resourceValues = try file.url.resourceValues(forKeys: resourceKeys)
        
        // Extract type values
        if let typeIdentifier = resourceValues.typeIdentifier {
            items.append(MetadataItem(
                key: "typeIdentifier",
                value: typeIdentifier,
                category: .basic,
                valueType: .uti
            ))
        }
        
        if let contentType = resourceValues.contentType {
            items.append(MetadataItem(
                key: "contentType",
                value: contentType.identifier,
                category: .basic,
                valueType: .uti
            ))
            
            // Add a user-friendly description if available
            items.append(MetadataItem(
                key: "contentTypeDescription",
                value: contentType.localizedDescription ?? "Unknown",
                category: .basic,
                valueType: .string
            ))
        }
        
        if let localizedTypeDescription = resourceValues.localizedTypeDescription {
            items.append(MetadataItem(
                key: "localizedTypeDescription",
                value: localizedTypeDescription,
                category: .basic,
                valueType: .string
            ))
        }
        
        // UTType conformance can be used instead of contentTypeTree
        if let typeIdentifier = resourceValues.typeIdentifier, let utType = UTType(typeIdentifier) {
            // Common types to check conformance against
            let commonTypes = [
                UTType.item,
                UTType.content,
                UTType.data,
                UTType.text,
                UTType.image,
                UTType.audio,
                UTType.video,
                UTType.package,
                UTType.directory,
                UTType.archive
            ]
            
            // Get conforming types
            var parentTypes: [String] = []
            
            for parentType in commonTypes {
                if utType.conforms(to: parentType) && utType.identifier != parentType.identifier {
                    parentTypes.append(parentType.identifier)
                }
            }
            
            if !parentTypes.isEmpty {
                items.append(MetadataItem(
                    key: "typeConformance",
                    value: parentTypes,
                    category: .extended,
                    valueType: .array
                ))
            }
        }
        
        return items
    }
    
    /// Extract file system attributes using FileManager
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for file system attributes
    private func extractFileSystemAttributes(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
        
        for (key, value) in attributes {
            // Skip certain attributes that we handle separately or are not useful
            if key == .size || key == .modificationDate || key == .creationDate {
                continue
            }
            
            // Format the key for display
            let formattedKey = String(describing: key)
                .replacingOccurrences(of: "kCFFileDescriptorAttributeKey", with: "")
                .replacingOccurrences(of: "NSFile", with: "")
            
            // Determine category
            let category: MetadataCategory
            if formattedKey.lowercased().contains("owner") || formattedKey.lowercased().contains("group") || 
               formattedKey.lowercased().contains("permission") || formattedKey.lowercased().contains("immutable") {
                category = .permissions
            } else {
                category = .filesystem
            }
            
            // Determine value type
            let valueType = MetadataValueType.detectType(of: value, key: formattedKey)
            
            // Create item
            let item = MetadataItem(key: formattedKey, value: value, category: category, valueType: valueType)
            items.append(item)
        }
        
    // Add filesystem-specific items
    do {
        // Check the volume properties directly from the file's URL
        // First, we get the mount point by going up the directory tree
        var volumeURL = file.url
        
        // Get file system info using statfs
        let fileSystemItems = try extractFileSystemInfo(file)
        items.append(contentsOf: fileSystemItems)
            
            // Keep going up until we reach the volume root
            while volumeURL.path != "/" && volumeURL.deletingLastPathComponent() != volumeURL {
                volumeURL = volumeURL.deletingLastPathComponent()
            }
            
            // Get volume attributes
            let volumeResourceKeys: Set<URLResourceKey> = [
                .volumeNameKey,
                .volumeLocalizedNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeSupportsVolumeSizesKey,
                .volumeSupportsPersistentIDsKey,
                .volumeSupportsSymbolicLinksKey,
                .volumeSupportsHardLinksKey,
                .volumeSupportsJournalingKey,
                .volumeIsJournalingKey,
                .volumeSupportsSparseFilesKey,
                .volumeSupportsZeroRunsKey,
                .volumeSupportsRootDirectoryDatesKey
            ]
            
            // Fetch volume resource values
            let volumeResourceValues = try volumeURL.resourceValues(forKeys: volumeResourceKeys)
            
            // Convert to dictionary for easier processing
            let mirror = Mirror(reflecting: volumeResourceValues)
            var volumeDict: [String: Any] = [:]
            
            for child in mirror.children {
                if let key = child.label, key != "allValues" {
                    // Skip nil values
                    if let optionalValue = Mirror(reflecting: child.value).displayStyle == .optional ? 
                        Mirror(reflecting: child.value).children.first?.value : child.value {
                        if !(optionalValue is NSNull) {
                            volumeDict["volume\(key.prefix(1).uppercased())\(key.dropFirst())"] = optionalValue
                        }
                    }
                }
            }
            
            // Create metadata items for volume attributes
            for (key, value) in volumeDict {
                let valueType = MetadataValueType.detectType(of: value, key: key)
                let item = MetadataItem(key: key, value: value, category: .filesystem, valueType: valueType)
                items.append(item)
            }
        } catch {
            // Just log the error but continue with other attributes
            logger.warning("Error getting volume attributes: \(error.localizedDescription)")
        }
        
        return items
    }
    
    /// Extract file system information using statfs
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for file system information
    private func extractFileSystemInfo(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        do {
            // This is a simplistic approach to get file system information
            let statOutput = try runTask("/usr/bin/stat", arguments: ["-f", file.url.path])
            let lines = statOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            if lines.count > 0 {
                // Parse the stat output to extract file system information
                // Example output format: "16777220 1152921500312772557 -rw-r--r-- 1 username staff 0 12 "filename" 0 0 1682377665 1682377665 1682377665 4096 8 0 0 0"
                let parts = lines[0].components(separatedBy: " ").filter { !$0.isEmpty }
                
                if parts.count >= 10 {
                    // Extract inode number
                    if let inodeNumber = Int64(parts[1]) {
                        items.append(MetadataItem(
                            key: "inodeNumber",
                            value: inodeNumber,
                            category: .filesystem,
                            valueType: .number
                        ))
                    }
                    
                    // Add blocks allocated (if available)
                    if parts.count > 12, let blocks = Int64(parts[12]) {
                        items.append(MetadataItem(
                            key: "blocksAllocated",
                            value: blocks,
                            category: .filesystem,
                            valueType: .number
                        ))
                    }
                    
                    // Add device ID (if available)
                    if let deviceID = Int64(parts[0]) {
                        items.append(MetadataItem(
                            key: "deviceID",
                            value: deviceID,
                            category: .filesystem,
                            valueType: .number
                        ))
                    }
                }
            }
            
            // Get more detailed file system information
            let fsOutput = try runTask("/usr/bin/df", arguments: ["-T", file.url.path])
            let fsLines = fsOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            if fsLines.count > 1 {
                // The second line contains the file system information
                let parts = fsLines[1].components(separatedBy: " ").filter { !$0.isEmpty }
                
                if parts.count >= 6 {
                    // Extract file system type
                    items.append(MetadataItem(
                        key: "filesystemType",
                        value: parts[1],
                        category: .filesystem,
                        valueType: .string
                    ))
                    
                    // Extract mount point
                    if parts.count >= 9 {
                        items.append(MetadataItem(
                            key: "mountPoint",
                            value: parts[8],
                            category: .filesystem,
                            valueType: .string
                        ))
                    }
                }
            }
        } catch {
            // Log but continue with other attributes
            logger.warning("Could not get file system info: \(error.localizedDescription)")
        }
        
        return items
    }
    
    /// Extract permission and ownership attributes
    /// - Parameter file: The file reference to extract from
    /// - Returns: Array of metadata items for permission attributes
    private func extractPermissionAttributes(_ file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get permission and ownership attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
        
        // Extract specific permission attributes
        let posixPermissions = attributes[.posixPermissions] as? NSNumber
        let ownerAccountName = attributes[.ownerAccountName] as? String
        let groupOwnerAccountName = attributes[.groupOwnerAccountName] as? String
        let ownerAccountID = attributes[.ownerAccountID] as? NSNumber
        let groupOwnerAccountID = attributes[.groupOwnerAccountID] as? NSNumber
        let immutable = attributes[.immutable] as? Bool
        let appendOnly = attributes[.appendOnly] as? Bool
        
        // Add formatted permission string (like "rwxr-xr--")
        if let permissions = posixPermissions?.intValue {
            let permissionString = formatPOSIXPermissions(permissions)
            items.append(MetadataItem(
                key: "formattedPermissions",
                value: permissionString,
                category: .permissions,
                valueType: .string
            ))
            
            // Also add permission parts
            items.append(MetadataItem(
                key: "ownerCanRead",
                value: (permissions & 0o400) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "ownerCanWrite",
                value: (permissions & 0o200) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "ownerCanExecute",
                value: (permissions & 0o100) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "groupCanRead",
                value: (permissions & 0o040) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "groupCanWrite",
                value: (permissions & 0o020) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "groupCanExecute",
                value: (permissions & 0o010) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "othersCanRead",
                value: (permissions & 0o004) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "othersCanWrite",
                value: (permissions & 0o002) != 0,
                category: .permissions,
                valueType: .boolean
            ))
            
            items.append(MetadataItem(
                key: "othersCanExecute",
                value: (permissions & 0o001) != 0,
                category: .permissions,
                valueType: .boolean
            ))
        }
        
        // Add owner information
        if let ownerName = ownerAccountName {
            items.append(MetadataItem(
                key: "ownerAccountName",
                value: ownerName,
                category: .permissions,
                valueType: .string
            ))
        }
        
        if let groupName = groupOwnerAccountName {
            items.append(MetadataItem(
                key: "groupOwnerAccountName",
                value: groupName,
                category: .permissions,
                valueType: .string
            ))
        }
        
        if let ownerID = ownerAccountID {
            items.append(MetadataItem(
                key: "ownerAccountID",
                value: ownerID,
                category: .permissions,
                valueType: .number
            ))
        }
        
        if let groupID = groupOwnerAccountID {
            items.append(MetadataItem(
                key: "groupOwnerAccountID",
                value: groupID,
                category: .permissions,
                valueType: .number
            ))
        }
        
        // Add file flags
        if let isImmutable = immutable {
            items.append(MetadataItem(
                key: "isImmutable",
                value: isImmutable,
                category: .permissions,
                valueType: .boolean
            ))
        }
        
        if let isAppendOnly = appendOnly {
            items.append(MetadataItem(
                key: "isAppendOnly",
                value: isAppendOnly,
                category: .permissions,
                valueType: .boolean
            ))
        }
        
        // Try to determine ACL information if available
        #if os(macOS)
        do {
            // This is a simplistic approach as full ACL parsing is complex
            let aclOutput = try runTask("/bin/ls", arguments: ["-le", file.url.path])
            if !aclOutput.isEmpty && aclOutput.contains(":") {
                let aclLines = aclOutput.components(separatedBy: "\n")
                    .filter { $0.contains(":") && $0.contains("user") || $0.contains("group") }
                
                if !aclLines.isEmpty {
                    items.append(MetadataItem(
                        key: "accessControlList",
                        value: aclLines.joined(separator: "\n"),
                        category: .permissions,
                        valueType: .string
                    ))
                }
            }
        } catch {
            // Just log and continue
            logger.warning("Could not get ACL info: \(error.localizedDescription)")
        }
        #endif
        
        return items
    }
    
    /// Format POSIX permissions into human-readable string (e.g., "rwxr-xr--")
    /// - Parameter permissions: The numeric permissions value
    /// - Returns: A formatted string representation
    private func formatPOSIXPermissions(_ permissions: Int) -> String {
        var result = ""
        
        // Owner permissions
        result += (permissions & 0o400) != 0 ? "r" : "-"
        result += (permissions & 0o200) != 0 ? "w" : "-"
        result += (permissions & 0o100) != 0 ? "x" : "-"
        
        // Group permissions
        result += (permissions & 0o040) != 0 ? "r" : "-"
        result += (permissions & 0o020) != 0 ? "w" : "-"
        result += (permissions & 0o010) != 0 ? "x" : "-"
        
        // Others permissions
        result += (permissions & 0o004) != 0 ? "r" : "-"
        result += (permissions & 0o002) != 0 ? "w" : "-"
        result += (permissions & 0o001) != 0 ? "x" : "-"
        
        return result
    }
    
    /// Run a command-line task and return the output
    /// - Parameters:
    ///   - launchPath: Path to the executable
    ///   - arguments: Array of arguments
    /// - Returns: Command output as string
    /// - Throws: Error if the task fails
    private func runTask(_ launchPath: String, arguments: [String]) throws -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        
        return output
    }
}
