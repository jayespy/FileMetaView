import Foundation
import SwiftUI

/// Represents a single metadata item associated with a file
struct MetadataItem: Identifiable, Hashable {
    /// Unique identifier for the metadata item (constructed from key and category)
    let id: String
    
    /// The key or name of the metadata attribute
    let key: String
    
    /// The display name for the metadata attribute (user-friendly version of key)
    let displayName: String
    
    /// The raw value of the metadata attribute
    let value: Any
    
    /// The category this metadata belongs to
    let category: MetadataCategory
    
    /// The type of the metadata value
    let valueType: MetadataValueType
    
    /// Initialize a metadata item
    /// - Parameters:
    ///   - key: The raw key for the metadata
    ///   - value: The raw value of the metadata
    ///   - category: The category this metadata belongs to
    ///   - valueType: The type of the metadata value
    init(key: String, value: Any, category: MetadataCategory, valueType: MetadataValueType) {
        self.key = key
        self.value = value
        self.category = category
        self.valueType = valueType
        
        // Create a user-friendly display name from the key
        self.displayName = key
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
        
        // Create a unique ID based on the key and category
        self.id = "\(category.rawValue)_\(key)"
    }
    
    /// Format the value based on its type for display purposes
    var formattedValue: String {
        return valueType.format(value)
    }
    
    /// Get a color for the category for display purposes
    var categoryColor: Color {
        return category.color
    }
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable Conformance
    
    static func == (lhs: MetadataItem, rhs: MetadataItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Helper Extensions

extension MetadataItem {
    /// Creates a metadata item from a resource value with a given key
    /// - Parameters:
    ///   - key: The URL resource key
    ///   - resourceValue: The value from URL resource values
    ///   - displayKey: Optional override for the display key
    /// - Returns: A metadata item, or nil if the value can't be processed
    static func fromResourceValue(key: URLResourceKey, resourceValue: Any?, displayKey: String? = nil) -> MetadataItem? {
        guard let value = resourceValue else { return nil }
        
        let metadataKey = displayKey ?? String(describing: key)
        let category = MetadataCategory.categorize(key: metadataKey)
        let valueType = MetadataValueType.detectType(of: value, key: metadataKey)
        
        // Convert the value to a more appropriate type if needed
        let convertedValue = valueType.convertValue(value)
        
        return MetadataItem(key: metadataKey, value: convertedValue, category: category, valueType: valueType)
    }
    
    /// Compare two metadata items for sorting
    /// - Parameters:
    ///   - lhs: First metadata item
    ///   - rhs: Second metadata item
    /// - Returns: Bool indicating sort order
    static func sortByCategory(_ lhs: MetadataItem, _ rhs: MetadataItem) -> Bool {
        if lhs.category == rhs.category {
            return lhs.displayName < rhs.displayName
        }
        return lhs.category.sortOrder < rhs.category.sortOrder
    }
}

// MARK: - Enums for Metadata Organization

// MetadataCategory has been moved to its own file (MetadataCategory.swift)

// MetadataValueType has been moved to its own file (MetadataValueType.swift)
