import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

/// Utility class for metadata operations across the application
class MetadataUtility {
    
    // MARK: - Metadata Formatting
    
    /// Format a metadata value based on its type
    /// - Parameters:
    ///   - value: The value to format
    ///   - valueType: The type of the value
    /// - Returns: A formatted string representation of the value
    static func formatValue(_ value: Any, ofType valueType: MetadataValueType) -> String {
        return valueType.format(value)
    }
    
    /// Format a date value with custom style
    /// - Parameters:
    ///   - date: The date to format
    ///   - dateStyle: The date style to use
    ///   - timeStyle: The time style to use
    /// - Returns: A formatted date string
    static func formatDate(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
    
    /// Format a file size value
    /// - Parameter bytes: The size in bytes
    /// - Returns: A formatted size string (e.g., "1.2 MB")
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Format a duration value
    /// - Parameter seconds: The duration in seconds
    /// - Returns: A formatted duration string (e.g., "2:30")
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: seconds) ?? "\(seconds) seconds"
    }
    
    // MARK: - Metadata Organization
    
    /// Categorize metadata items by their category
    /// - Parameter items: The metadata items to categorize
    /// - Returns: A dictionary mapping categories to arrays of items
    static func groupItemsByCategory(_ items: [MetadataItem]) -> [MetadataCategory: [MetadataItem]] {
        var groupedItems: [MetadataCategory: [MetadataItem]] = [:]
        
        for item in items {
            if groupedItems[item.category] == nil {
                groupedItems[item.category] = []
            }
            groupedItems[item.category]?.append(item)
        }
        
        return groupedItems
    }
    
    /// Filter metadata items by search text
    /// - Parameters:
    ///   - items: The metadata items to filter
    ///   - searchText: The search text to filter by
    /// - Returns: Filtered array of metadata items
    static func filterItems(_ items: [MetadataItem], by searchText: String) -> [MetadataItem] {
        guard !searchText.isEmpty else { return items }
        
        let lowercasedSearch = searchText.lowercased()
        return items.filter { item in
            item.displayName.lowercased().contains(lowercasedSearch) ||
            item.formattedValue.lowercased().contains(lowercasedSearch) ||
            item.key.lowercased().contains(lowercasedSearch)
        }
    }
    
    /// Filter metadata items by categories
    /// - Parameters:
    ///   - items: The metadata items to filter
    ///   - categories: The categories to include
    /// - Returns: Filtered array of metadata items
    static func filterItems(_ items: [MetadataItem], categories: [MetadataCategory]) -> [MetadataItem] {
        guard !categories.isEmpty else { return items }
        
        return items.filter { item in
            categories.contains(item.category)
        }
    }
    
    /// Sort metadata items by various criteria
    /// - Parameters:
    ///   - items: The metadata items to sort
    ///   - sortOption: The sorting option to use
    /// - Returns: Sorted array of metadata items
    static func sortItems(_ items: [MetadataItem], by sortOption: SortOption) -> [MetadataItem] {
        switch sortOption {
        case .category:
            return items.sorted(by: MetadataItem.sortByCategory)
            
        case .keyAscending:
            return items.sorted { $0.displayName < $1.displayName }
            
        case .keyDescending:
            return items.sorted { $0.displayName > $1.displayName }
            
        case .valueType:
            return items.sorted { $0.valueType.rawValue < $1.valueType.rawValue }
        }
    }
    
    /// Sorting options for metadata items
    enum SortOption {
        case category       // Sort by category and then key
        case keyAscending   // Sort by key name (A-Z)
        case keyDescending  // Sort by key name (Z-A)
        case valueType      // Sort by value type
    }
    
    // MARK: - Value Type Detection
    
    /// Detect the type of a value
    /// - Parameters:
    ///   - value: The value to detect the type of
    ///   - key: Optional context key for better detection
    /// - Returns: The detected metadata value type
    static func detectValueType(of value: Any, key: String? = nil) -> MetadataValueType {
        if let contextKey = key {
            return MetadataValueType.detectType(of: value, key: contextKey)
        } else {
            return MetadataValueType.detectType(of: value)
        }
    }
    
    // MARK: - String Utilities
    
    /// Format a raw key into a user-friendly display name
    /// - Parameter key: The raw key to format
    /// - Returns: A formatted display name
    static func formatKeyToDisplayName(_ key: String) -> String {
        return key
            .replacingOccurrences(of: "kMDItem", with: "")
            .replacingOccurrences(of: "com_apple_", with: "")
            .replacingOccurrences(of: "public_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .split(separator: " ")
            .map { word in
                let firstChar = String(word.prefix(1)).capitalized
                let restOfWord = String(word.dropFirst())
                return firstChar + restOfWord
            }
            .joined(separator: " ")
    }
    
    /// Convert camelCase to words with spaces
    /// - Parameter camelCase: A camelCase string
    /// - Returns: A string with spaces between words
    static func camelCaseToWords(_ camelCase: String) -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: camelCase.count)
        let result = regex?.stringByReplacingMatches(
            in: camelCase,
            options: [],
            range: range,
            withTemplate: "$1 $2"
        )
        return result?.capitalized ?? camelCase.capitalized
    }
    
    // MARK: - File Type Utilities
    
    /// Check if a file type conforms to a standard type
    /// - Parameters:
    ///   - fileType: The file type to check
    ///   - standardType: The standard type to check against
    /// - Returns: Boolean indicating if the file type conforms to the standard type
    static func fileTypeConforms(_ fileType: String, to standardType: UTType) -> Bool {
        guard let type = UTType(fileType) else { return false }
        return type.conforms(to: standardType)
    }
    
    /// Get a list of common file type categories
    /// - Returns: Array of common file type categories
    static func commonFileTypeCategories() -> [UTType] {
        return [
            .content,
            .image,
            .audio,
            .movie,
            .text,
            .pdf,
            .spreadsheet,
            .presentation,
            .database,
            .archive,
            .executable
        ]
    }
    
    /// Get a readable description for a UTI
    /// - Parameter uti: The UTI string
    /// - Returns: A human-readable description
    static func descriptionForUTI(_ uti: String) -> String {
        guard let utType = UTType(uti) else {
            return uti
        }
        return utType.localizedDescription ?? uti
    }
    
    // MARK: - Dictionary Utilities
    
    /// Convert a dictionary to metadata items
    /// - Parameters:
    ///   - dict: The dictionary to convert
    ///   - categoryMapper: Optional function to map keys to categories
    /// - Returns: Array of metadata items
    static func createMetadataItems(from dict: [String: Any], categoryMapper: ((String) -> MetadataCategory)? = nil) -> [MetadataItem] {
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
    
    /// Create a dictionary from metadata items
    /// - Parameter items: The metadata items to convert
    /// - Returns: A dictionary of key-value pairs
    static func createDictionary(from items: [MetadataItem]) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        for item in items {
            dict[item.key] = item.value
        }
        
        return dict
    }
    
    // MARK: - Resource Value Conversions
    
    /// Create metadata items from URL resource values
    /// - Parameters:
    ///   - resourceValues: The resource values to convert
    ///   - fileReference: Optional file reference for context
    /// - Returns: Array of metadata items
    static func createItems(from resourceValues: URLResourceValues, fileReference: FileReference? = nil) -> [MetadataItem] {
        var items: [MetadataItem] = []
        
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
        
        // Create metadata items
        for (key, value) in resourceDict {
            // Determine category based on key and file reference
            let category: MetadataCategory
            if let fileRef = fileReference {
                category = MetadataCategory.categorize(key: key, fileReference: fileRef)
            } else {
                category = MetadataCategory.categorize(key: key)
            }
            
            // Determine value type
            let valueType = MetadataValueType.detectType(of: value, key: key)
            
            // Create item
            let item = MetadataItem(key: key, value: value, category: category, valueType: valueType)
            items.append(item)
        }
        
        return items
    }
    
    // MARK: - Error Handling
    
    /// Convert system errors to FileAccessError
    /// - Parameters:
    ///   - error: The error to convert
    ///   - file: The file reference involved
    ///   - context: Optional context message
    /// - Returns: A FileAccessError appropriate for the situation
    static func handleFileError(_ error: Error, file: FileReference, context: String = "") -> FileAccessError {
        // If it's already a FileAccessError, return it
        if let fileError = error as? FileAccessError {
            return fileError
        }
        
        // Use the from method in FileAccessError
        return FileAccessError.from(error: error, url: file.url)
    }
    
    // MARK: - Limiting & Selection
    
    /// Limit the number of metadata items
    /// - Parameters:
    ///   - items: The items to limit
    ///   - maxItems: The maximum number of items to return (defaults to 30 per application requirement)
    /// - Returns: A limited array of items
    static func limitItems(_ items: [MetadataItem], to maxItems: Int = 30) -> [MetadataItem] {
        guard items.count > maxItems else { return items }
        
        // We want to keep the most important items
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
        return Array(sortedItems.prefix(maxItems))
    }
    
    /// Select important metadata items for summary display
    /// - Parameter items: All metadata items
    /// - Returns: A subset of items for summary display
    static func selectSummaryItems(_ items: [MetadataItem]) -> [MetadataItem] {
        // Important keys to look for
        let importantKeys = [
            "name", "size", "creationDate", "modificationDate", "type", 
            "kind", "dimensions", "duration", "author", "title"
        ]
        
        // First try to find important keys
        var summaryItems = items.filter { item in
            importantKeys.contains { importantKey in
                item.key.lowercased().contains(importantKey.lowercased())
            }
        }
        
        // If we don't have enough items, add more from the basic category
        if summaryItems.count < 5 {
            let basicItems = items.filter { $0.category == .basic }
                .filter { !summaryItems.contains($0) }
            
            summaryItems.append(contentsOf: basicItems.prefix(5 - summaryItems.count))
        }
        
        return summaryItems
    }
}
