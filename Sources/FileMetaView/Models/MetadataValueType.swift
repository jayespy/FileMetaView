import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

/// Types of metadata values for proper formatting and display
enum MetadataValueType: String, CaseIterable, Identifiable {
    // Basic types
    case string = "string"           // Text values
    case number = "number"           // Numeric values (int, double, etc.)
    case date = "date"               // Date and time values
    case boolean = "boolean"         // Boolean values (true/false)
    
    // Special formats
    case fileSize = "fileSize"       // File size in bytes
    case duration = "duration"       // Time duration (seconds, minutes, etc.)
    case percentage = "percentage"   // Percentage values
    case coordinate = "coordinate"   // Geographic coordinates
    case currency = "currency"       // Monetary values
    
    // Complex types
    case data = "data"               // Binary data
    case color = "color"             // Color values
    case array = "array"             // Array of values
    case dictionary = "dictionary"   // Dictionary/map of values
    case url = "url"                 // URL/URI values
    case uti = "uti"                 // Uniform Type Identifier
    
    // Special cases
    case image = "image"             // Image data
    case rating = "rating"           // Rating values (stars, etc.)
    case enumeration = "enumeration" // Enumerated values
    case unknown = "unknown"         // Unrecognized types
    
    /// Identifier for Identifiable conformance
    var id: String { self.rawValue }
    
    /// Display name for the value type
    var displayName: String {
        switch self {
        case .string:       return "Text"
        case .number:       return "Number"
        case .date:         return "Date/Time"
        case .boolean:      return "Yes/No"
        case .fileSize:     return "File Size"
        case .duration:     return "Duration"
        case .percentage:   return "Percentage"
        case .coordinate:   return "Coordinates"
        case .currency:     return "Currency"
        case .data:         return "Binary Data"
        case .color:        return "Color"
        case .array:        return "List"
        case .dictionary:   return "Dictionary"
        case .url:          return "URL"
        case .uti:          return "Type Identifier"
        case .image:        return "Image"
        case .rating:       return "Rating"
        case .enumeration:  return "Selection"
        case .unknown:      return "Unknown"
        }
    }
    
    /// Description for the value type
    var description: String {
        switch self {
        case .string:       return "Text value such as a name or description."
        case .number:       return "Numeric value such as a count or measurement."
        case .date:         return "Date and time value."
        case .boolean:      return "Boolean value (true/false, yes/no)."
        case .fileSize:     return "Size of a file in bytes."
        case .duration:     return "Time duration in seconds, minutes, hours, etc."
        case .percentage:   return "Percentage value (0-100%)."
        case .coordinate:   return "Geographic coordinates (latitude/longitude)."
        case .currency:     return "Monetary value with currency information."
        case .data:         return "Binary data block."
        case .color:        return "Color value with RGB or other color model."
        case .array:        return "Collection of multiple values."
        case .dictionary:   return "Collection of key-value pairs."
        case .url:          return "Web or file URL reference."
        case .uti:          return "Uniform Type Identifier for file types."
        case .image:        return "Image data, possibly with thumbnail."
        case .rating:       return "Rating value (e.g., 1-5 stars)."
        case .enumeration:  return "Value from a predefined set of options."
        case .unknown:      return "Value of an unknown or unrecognized type."
        }
    }
    
    /// SF Symbol icon name associated with this value type
    var iconName: String {
        switch self {
        case .string:       return "text.quote"
        case .number:       return "number"
        case .date:         return "calendar"
        case .boolean:      return "checkmark.circle"
        case .fileSize:     return "externaldrive"
        case .duration:     return "clock"
        case .percentage:   return "percent"
        case .coordinate:   return "location"
        case .currency:     return "dollarsign.circle"
        case .data:         return "doc.binary"
        case .color:        return "paintpalette"
        case .array:        return "list.bullet"
        case .dictionary:   return "list.bullet.indent"
        case .url:          return "link"
        case .uti:          return "doc.badge.gearshape"
        case .image:        return "photo"
        case .rating:       return "star"
        case .enumeration:  return "list.bullet.rectangle"
        case .unknown:      return "questionmark.circle"
        }
    }
    
    /// Color associated with this value type for UI display
    var color: Color {
        switch self {
        case .string:       return .blue
        case .number:       return .green
        case .date:         return .orange
        case .boolean:      return .purple
        case .fileSize:     return .gray
        case .duration:     return .pink
        case .percentage:   return .yellow
        case .coordinate:   return .red
        case .currency:     return .green
        case .data:         return .gray
        case .color:        return .pink
        case .array:        return .orange
        case .dictionary:   return .indigo
        case .url:          return .blue
        case .uti:          return .gray
        case .image:        return .purple
        case .rating:       return .yellow
        case .enumeration:  return .teal
        case .unknown:      return .gray
        }
    }
    
    /// Format a value according to its type
    /// - Parameter value: The value to format
    /// - Returns: A formatted string representation of the value
    func format(_ value: Any) -> String {
        switch self {
        case .string:
            if let stringValue = value as? String {
                return stringValue
            }
            return String(describing: value)
            
        case .number:
            if let intValue = value as? Int {
                return String(intValue)
            } else if let doubleValue = value as? Double {
                // Format with appropriate decimal places
                if doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f", doubleValue)
                } else {
                    return String(format: "%.2f", doubleValue)
                }
            } else if let floatValue = value as? Float {
                if floatValue.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f", floatValue)
                } else {
                    return String(format: "%.2f", floatValue)
                }
            } else if let int64Value = value as? Int64 {
                return String(int64Value)
            }
            return String(describing: value)
            
        case .date:
            if let dateValue = value as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                return formatter.string(from: dateValue)
            }
            return "Invalid date"
            
        case .boolean:
            if let boolValue = value as? Bool {
                return boolValue ? "Yes" : "No"
            }
            return "Invalid boolean"
            
        case .fileSize:
            if let sizeValue = value as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: sizeValue)
            } else if let sizeValue = value as? Int {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useAll]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(sizeValue))
            }
            return "Invalid file size"
            
        case .duration:
            if let durationValue = value as? TimeInterval {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = durationValue >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
                formatter.unitsStyle = .abbreviated
                formatter.zeroFormattingBehavior = .dropLeading
                return formatter.string(from: durationValue) ?? "\(durationValue) seconds"
            } else if let secondsValue = value as? Int {
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = secondsValue >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
                formatter.unitsStyle = .abbreviated
                formatter.zeroFormattingBehavior = .dropLeading
                return formatter.string(from: TimeInterval(secondsValue)) ?? "\(secondsValue) seconds"
            }
            return "Invalid duration"
            
        case .percentage:
            if let doubleValue = value as? Double {
                return String(format: "%.1f%%", doubleValue)
            } else if let intValue = value as? Int {
                return "\(intValue)%"
            }
            return "Invalid percentage"
            
        case .coordinate:
            if let coordValue = value as? CLLocationCoordinate2D {
                return String(format: "%.6f, %.6f", coordValue.latitude, coordValue.longitude)
            } else if let arrayValue = value as? [Double], arrayValue.count >= 2 {
                return String(format: "%.6f, %.6f", arrayValue[0], arrayValue[1])
            }
            return "Invalid coordinates"
            
        case .currency:
            if let doubleValue = value as? Double {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = Locale.current
                return formatter.string(from: NSNumber(value: doubleValue)) ?? String(format: "$%.2f", doubleValue)
            }
            return "Invalid currency"
            
        case .data:
            if let dataValue = value as? Data {
                return "\(dataValue.count) bytes"
            }
            return "Binary data"
            
        case .color:
            // For color values, just return a simple description
            return "Color value"
            
        case .array:
            if let arrayValue = value as? [Any] {
                if arrayValue.isEmpty {
                    return "(Empty list)"
                }
                return arrayValue.map { String(describing: $0) }.joined(separator: ", ")
            }
            return "Invalid list"
            
        case .dictionary:
            if let dictValue = value as? [String: Any] {
                if dictValue.isEmpty {
                    return "(Empty dictionary)"
                }
                let pairs = dictValue.map { key, value in "\(key): \(String(describing: value))" }
                return pairs.joined(separator: ", ")
            }
            return "Invalid dictionary"
            
        case .url:
            if let urlValue = value as? URL {
                return urlValue.absoluteString
            } else if let stringValue = value as? String, let _ = URL(string: stringValue) {
                return stringValue
            }
            return "Invalid URL"
            
        case .uti:
            if let utiValue = value as? String {
                // Try to get a more user-friendly description if possible
                if let utType = UTType(utiValue) {
                    return utType.localizedDescription ?? utiValue
                }
                return utiValue
            }
            return "Invalid type identifier"
            
        case .image:
            // For image data, just return a simple description
            if let dataValue = value as? Data {
                return "Image data (\(dataValue.count) bytes)"
            }
            return "Image data"
            
        case .rating:
            if let ratingValue = value as? Int {
                return String(repeating: "★", count: ratingValue) + String(repeating: "☆", count: 5 - ratingValue)
            } else if let doubleValue = value as? Double {
                let intPart = Int(doubleValue)
                return String(repeating: "★", count: intPart) + String(repeating: "☆", count: 5 - intPart)
            }
            return "Invalid rating"
            
        case .enumeration:
            return String(describing: value)
            
        case .unknown:
            return String(describing: value)
        }
    }
    
    /// Detect the most appropriate type for a given value
    /// - Parameter value: The value to analyze
    /// - Returns: The detected MetadataValueType
    static func detectType(of value: Any) -> MetadataValueType {
        // Check for NSNull values
        if value is NSNull {
            return .string // Represent nil values as empty strings
        }
        
        // Check specific types
        switch value {
        case is String:
            let stringValue = value as! String
            
            // Check if it might be a URL
            if stringValue.starts(with: "http://") || 
               stringValue.starts(with: "https://") || 
               stringValue.starts(with: "file://") {
                return .url
            }
            
            // Check if it might be a UTI
            if stringValue.contains("public.") || 
               stringValue.contains("com.apple.") || 
               stringValue.contains("dyn.") {
                return .uti
            }
            
            return .string
            
        case is Date:
            return .date
            
        case is Bool:
            return .boolean
            
        case is Int, is Double, is Float, is Int64, is Int32, is Int16, is Int8, is UInt, is UInt64, is UInt32, is UInt16, is UInt8:
            // Try to determine special number types based on context
            let keyPath = Thread.current.threadDictionary["currentMetadataKey"] as? String ?? ""
            let lowerKey = keyPath.lowercased()
            
            if lowerKey.contains("size") && (lowerKey.contains("file") || lowerKey.contains("disk")) {
                return .fileSize
            } else if lowerKey.contains("duration") || lowerKey.contains("time") || lowerKey.contains("seconds") {
                return .duration
            } else if lowerKey.contains("percent") || lowerKey.contains("ratio") || lowerKey.contains("completion") {
                return .percentage
            } else if lowerKey.contains("rating") || lowerKey.contains("stars") || lowerKey.contains("score") {
                return .rating
            } else if lowerKey.contains("currency") || lowerKey.contains("price") || lowerKey.contains("cost") {
                return .currency
            } else {
                return .number
            }
            
        case is Data:
            // Try to determine if it's image data based on context
            let keyPath = Thread.current.threadDictionary["currentMetadataKey"] as? String ?? ""
            let lowerKey = keyPath.lowercased()
            
            if lowerKey.contains("image") || lowerKey.contains("thumbnail") || lowerKey.contains("icon") {
                return .image
            } else {
                return .data
            }
            
        case is NSArray, is [Any]:
            return .array
            
        case is NSDictionary, is [String: Any]:
            return .dictionary
            
        case is URL:
            return .url
            
        case is CGColor, is NSColor:
            return .color
            
        case is CLLocationCoordinate2D:
            return .coordinate
            
        case is FileAttributeKey:
            return .string
            
        default:
            // Check if it's an enumeration or other special case
            let mirror = Mirror(reflecting: value)
            if mirror.displayStyle == .enum {
                return .enumeration
            }
            
            // Fall back to unknown for unsupported types
            return .unknown
        }
    }
    
    /// Detect type based on both value and key context
    /// - Parameters:
    ///   - value: The value to analyze
    ///   - key: The metadata key for context
    /// - Returns: The detected MetadataValueType
    static func detectType(of value: Any, key: String) -> MetadataValueType {
        // Store the key in thread dictionary for context in the main detectType method
        Thread.current.threadDictionary["currentMetadataKey"] = key
        defer { Thread.current.threadDictionary["currentMetadataKey"] = nil }
        
        // First get the base type
        let baseType = detectType(of: value)
        
        // If it's already a specific type, return it
        if baseType != .string && baseType != .number && baseType != .unknown {
            return baseType
        }
        
        // Try to refine the type based on the key
        let lowerKey = key.lowercased()
        
        if baseType == .string {
            if lowerKey.contains("url") || lowerKey.contains("uri") || lowerKey.contains("link") {
                return .url
            } else if lowerKey.contains("type") || lowerKey.contains("uti") || lowerKey.contains("identifier") {
                return .uti
            }
        } else if baseType == .number {
            if lowerKey.contains("size") || lowerKey.contains("bytes") || lowerKey.contains("length") {
                return .fileSize
            } else if lowerKey.contains("duration") || lowerKey.contains("time") || lowerKey.contains("seconds") {
                return .duration
            } else if lowerKey.contains("percent") || lowerKey.contains("ratio") || lowerKey.contains("completion") {
                return .percentage
            } else if lowerKey.contains("rating") || lowerKey.contains("stars") || lowerKey.contains("score") {
                return .rating
            } else if lowerKey.contains("currency") || lowerKey.contains("price") || lowerKey.contains("cost") {
                return .currency
            }
        }
        
        return baseType
    }
}

// MARK: - Extensions for working with MetadataValueType

extension MetadataValueType {
    /// Convert a value to a more appropriate Swift type based on the metadata type
    /// - Parameter value: The value to convert
    /// - Returns: The converted value, or the original if no conversion is needed
    func convertValue(_ value: Any) -> Any {
        switch self {
        case .fileSize:
            if let numberValue = value as? NSNumber {
                return Int64(truncating: numberValue)
            }
            return value
            
        case .date:
            if let timeIntervalValue = value as? TimeInterval {
                return Date(timeIntervalSinceReferenceDate: timeIntervalValue)
            }
            return value
            
        case .url:
            if let stringValue = value as? String, let url = URL(string: stringValue) {
                return url
            }
            return value
            
        case .number:
            if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                return doubleValue
            }
            return value
            
        case .boolean:
            if let intValue = value as? Int {
                return intValue != 0
            } else if let stringValue = value as? String {
                let lowercased = stringValue.lowercased()
                if ["true", "yes", "1"].contains(lowercased) {
                    return true
                } else if ["false", "no", "0"].contains(lowercased) {
                    return false
                }
            }
            return value
            
        default:
            return value
        }
    }
    
    /// Check if the value is considered empty for this type
    /// - Parameter value: The value to check
    /// - Returns: True if the value is empty or nil
    func isEmpty(_ value: Any?) -> Bool {
        guard let value = value else { return true }
        
        switch self {
        case .string:
            if let stringValue = value as? String {
                return stringValue.isEmpty
            }
            return false
            
        case .array:
            if let arrayValue = value as? [Any] {
                return arrayValue.isEmpty
            }
            return false
            
        case .dictionary:
            if let dictValue = value as? [String: Any] {
                return dictValue.isEmpty
            }
            return false
            
        case .data:
            if let dataValue = value as? Data {
                return dataValue.isEmpty
            }
            return false
            
        default:
            return false
        }
    }
}
