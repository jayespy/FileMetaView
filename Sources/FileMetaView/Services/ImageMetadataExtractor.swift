import Foundation
import UniformTypeIdentifiers
import ImageIO
import os.log
import CoreGraphics
import CoreImage

/// A metadata extractor specialized for image files (JPEG, PNG, HEIC, etc.)
class ImageMetadataExtractor: MetadataExtractor {
    /// Logger for this extractor
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "ImageMetadataExtractor")
    
    /// Image UTI types this extractor can handle
    private let supportedImageTypes = [
        UTType.jpeg.identifier,
        UTType.png.identifier,
        UTType.tiff.identifier,
        UTType.heic.identifier,
        UTType.heif.identifier,
        UTType.gif.identifier,
        UTType.bmp.identifier,
        "public.webp",          // webP
        "public.camera-raw-image" // RAW
    ]
    
    /// Image file extensions this extractor can handle
    private let supportedImageExtensions = [
        "jpg", "jpeg", "png", "tiff", "tif", "heic", "heif",
        "gif", "bmp", "webp", "raw", "arw", "cr2", "nef", "orf", "dng"
    ]
    
    /// Initialize a new ImageMetadataExtractor
    init() {}
    
    /// Extract metadata from an image file
    /// - Parameter file: The file reference to extract metadata from
    /// - Returns: An array of metadata items
    /// - Throws: FileAccessError if extraction fails
    func extractMetadata(from file: FileReference) async throws -> [MetadataItem] {
        logger.info("Extracting image metadata for file: \(file.url.lastPathComponent)")
        
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
            // Create image source
            guard let imageSource = CGImageSourceCreateWithURL(file.url as CFURL, nil) else {
                throw MetadataExtractionError.resourceAccessFailed("Could not create image source")
            }
            
            // Extract basic image properties
            let basicItems = try extractBasicImageProperties(imageSource, file: file)
            items.append(contentsOf: basicItems)
            
            // Extract EXIF data
            let exifItems = try extractEXIFData(imageSource, file: file)
            items.append(contentsOf: exifItems)
            
            // Extract IPTC data
            let iptcItems = try extractIPTCData(imageSource, file: file)
            items.append(contentsOf: iptcItems)
            
            // Extract GPS data
            let gpsItems = try extractGPSData(imageSource, file: file)
            items.append(contentsOf: gpsItems)
            
            // Extract color profile data
            let colorItems = try extractColorProfileData(imageSource, file: file)
            items.append(contentsOf: colorItems)
            
            // Limit the number of items and return
            return limitItems(items)
        } catch let error as MetadataExtractionError {
            logger.error("Error extracting image metadata: \(error)")
            switch error {
            case .unsupportedFileType(let message):
                throw FileAccessError.unsupportedFileType(file.url, message)
            case .metadataParsingFailed(_):
                throw FileAccessError.metadataExtractionFailed(file.url, error)
            case .resourceAccessFailed(_):
                throw FileAccessError.readError(file.url, error)
            case .malformedFile(_):
                throw FileAccessError.readError(file.url, error)
            case .fileTooLargeForExtractor(let fileSize, _):
                throw FileAccessError.fileTooLarge(file.url, fileSize)
            case .processingTooIntensive(_):
                throw FileAccessError.metadataExtractionFailed(file.url, error)
            case .extractionTimeout(let seconds):
                throw FileAccessError.timeout(file.url, "Image metadata extraction timed out after \(Int(seconds)) seconds")
            case .operationCancelled(let message):
                throw FileAccessError.operationCancelled(message)
            }
        } catch {
            logger.error("Error extracting image metadata: \(error.localizedDescription)")
            throw handleExtractionError(error, file: file, context: "Image metadata extraction")
        }
    }
    
    /// Check if this extractor can handle a specific file type
    /// - Parameters:
    ///   - fileType: The UTI string of the file
    ///   - fileExtension: Optional file extension as fallback
    /// - Returns: Boolean indicating if this extractor can handle the file type
    func canHandle(fileType: String, fileExtension: String?) -> Bool {
        // Check by UTI conformance to image type
        if utiConforms(fileType, to: UTType.image.identifier) {
            return true
        }
        
        // Check by specific UTI types
        if supportedImageTypes.contains(fileType) {
            return true
        }
        
        // Check by extension if UTI checks failed
        if let ext = fileExtension?.lowercased(), supportedImageExtensions.contains(ext) {
            return true
        }
        
        return false
    }
    
    /// Name of this extractor for identification
    /// - Returns: String identifier for this extractor type
    func extractorName() -> String {
        return "Image Metadata Extractor"
    }
    
    /// Description of the types of metadata this extractor provides
    /// - Returns: Human-readable description
    func extractorDescription() -> String {
        return "Extracts metadata from image files including EXIF, IPTC, and color profile information"
    }
    
    /// Categories of metadata this extractor can provide
    /// - Returns: Array of metadata categories this extractor handles
    func providedCategories() -> [MetadataCategory] {
        return [.image]
    }
    
    /// Priority of this extractor relative to others
    /// - Returns: Priority value (higher values indicate higher priority)
    func priority() -> Int {
        // Image metadata extractor has high priority for image files
        return 8
    }
    
    /// Performance impact rating of this extractor (1-10)
    /// - Returns: Rating where higher values indicate more resource-intensive processing
    func performanceImpact() -> Int {
        // Image metadata extraction is moderately resource-intensive
        return 5
    }
    
    /// Recommended file size limit for this extractor
    /// - Returns: Maximum recommended file size in bytes, or nil for no limit
    func recommendedFileSizeLimit() -> Int64? {
        // For image files, reasonable limit is 200MB
        return 200 * 1024 * 1024
    }
    
    // MARK: - Private Methods
    
    /// Extract basic image properties (dimensions, format, etc.)
    /// - Parameters:
    ///   - imageSource: The CGImageSource to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for basic image properties
    private func extractBasicImageProperties(_ imageSource: CGImageSource, file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get the image properties dictionary
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            // Get basic image properties
            
            // Dimensions
            if let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
               let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                items.append(MetadataItem(
                    key: "pixelWidth",
                    value: width,
                    category: .image,
                    valueType: .number
                ))
                
                items.append(MetadataItem(
                    key: "pixelHeight",
                    value: height,
                    category: .image,
                    valueType: .number
                ))
                
                // Add combined dimensions for convenience
                items.append(MetadataItem(
                    key: "dimensions",
                    value: "\(width) × \(height)",
                    category: .image,
                    valueType: .string
                ))
            }
            
            // DPI/Resolution
            if let dpiWidth = properties[kCGImagePropertyDPIWidth as String] as? Double {
                items.append(MetadataItem(
                    key: "dpiWidth",
                    value: dpiWidth,
                    category: .image,
                    valueType: .number
                ))
            }
            
            if let dpiHeight = properties[kCGImagePropertyDPIHeight as String] as? Double {
                items.append(MetadataItem(
                    key: "dpiHeight",
                    value: dpiHeight,
                    category: .image,
                    valueType: .number
                ))
            }
            
            // Orientation
            if let orientation = properties[kCGImagePropertyOrientation as String] as? Int {
                // Convert orientation number to human-readable description
                let orientationDescription: String
                switch orientation {
                case 1: orientationDescription = "Normal"
                case 2: orientationDescription = "Mirrored horizontally"
                case 3: orientationDescription = "Rotated 180°"
                case 4: orientationDescription = "Mirrored vertically"
                case 5: orientationDescription = "Mirrored horizontally, rotated 90° CCW"
                case 6: orientationDescription = "Rotated 90° CW"
                case 7: orientationDescription = "Mirrored horizontally, rotated 90° CW"
                case 8: orientationDescription = "Rotated 90° CCW"
                default: orientationDescription = "Unknown (\(orientation))"
                }
                
                items.append(MetadataItem(
                    key: "orientation",
                    value: orientationDescription,
                    category: .image,
                    valueType: .string
                ))
            }
            
            // Color model
            if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
                items.append(MetadataItem(
                    key: "colorModel",
                    value: colorModel,
                    category: .image,
                    valueType: .string
                ))
            }
            
            // Depth
            if let depth = properties[kCGImagePropertyDepth as String] as? Int {
                items.append(MetadataItem(
                    key: "bitsPerComponent",
                    value: depth,
                    category: .image,
                    valueType: .number
                ))
            }
            
            // Has alpha
            if let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool {
                items.append(MetadataItem(
                    key: "hasAlpha",
                    value: hasAlpha,
                    category: .image,
                    valueType: .boolean
                ))
            }
            
            // Image format-specific properties
            let formatTypes = [
                (kCGImagePropertyFileContentsDictionary as String, "File Contents"),
                (kCGImagePropertyPNGDictionary as String, "PNG"),
                (kCGImagePropertyGIFDictionary as String, "GIF"),
                (kCGImagePropertyJFIFDictionary as String, "JFIF"),
                (kCGImagePropertyTIFFDictionary as String, "TIFF"),
                ("{HEICS}" as String, "HEICS"),
                ("{HEIF}" as String, "HEIF"),
                ("{DNG}" as String, "DNG"),
                ("{RAW}" as String, "RAW")
            ]
            
            for (propKey, formatName) in formatTypes {
                if let formatDict = properties[propKey] as? [String: Any], !formatDict.isEmpty {
                    items.append(MetadataItem(
                        key: "format",
                        value: formatName,
                        category: .image,
                        valueType: .string
                    ))
                    
                    // Add specific format properties
                    for (key, value) in formatDict {
                        // Skip items that will be covered in other sections
                        if key.contains("EXIF") || key.contains("IPTC") || key.contains("GPS") {
                            continue
                        }
                        
                        let formattedKey = formatName.lowercased() + MetadataUtility.camelCaseToWords(key)
                        let valueType = MetadataValueType.detectType(of: value)
                        
                        items.append(MetadataItem(
                            key: formattedKey,
                            value: value,
                            category: .image,
                            valueType: valueType
                        ))
                    }
                    
                    // We only need the first matched format
                    break
                }
            }
            
            // Add any other properties that aren't in special dictionaries
            for (key, value) in properties {
                // Skip properties we already processed or that are in special dictionaries
                if key == kCGImagePropertyPixelWidth as String ||
                   key == kCGImagePropertyPixelHeight as String ||
                   key == kCGImagePropertyDPIWidth as String ||
                   key == kCGImagePropertyDPIHeight as String ||
                   key == kCGImagePropertyOrientation as String ||
                   key == kCGImagePropertyColorModel as String ||
                   key == kCGImagePropertyDepth as String ||
                   key == kCGImagePropertyHasAlpha as String ||
                   key.hasSuffix("Dictionary") {
                    continue
                }
                
                // Format the key
                let formattedKey = key
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")
                    .replacingOccurrences(of: "kCGImageProperty", with: "")
                
                // Determine value type
                let valueType = MetadataValueType.detectType(of: value)
                
                items.append(MetadataItem(
                    key: formattedKey,
                    value: value,
                    category: .image,
                    valueType: valueType
                ))
            }
        }
        
        return items
    }
    
    /// Extract EXIF data from an image
    /// - Parameters:
    ///   - imageSource: The CGImageSource to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for EXIF data
    private func extractEXIFData(_ imageSource: CGImageSource, file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get the image properties dictionary
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            // Get EXIF data if available
            if let exifDict = properties["{Exif}" as String] as? [String: Any] {
                // Process common EXIF properties
                let commonExifProps = [
                    // Camera information
                    ("{Exif}Make" as String, "cameraMake"),
                    ("{Exif}Model" as String, "cameraModel"),
                    ("{Exif}Software" as String, "software"),
                    
                    // Capture details
                    ("{Exif}DateTimeOriginal" as String, "dateTimeOriginal"),
                    ("{Exif}DateTimeDigitized" as String, "dateTimeDigitized"),
                    ("{Exif}SubsecTimeOriginal" as String, "subsecTimeOriginal"),
                    
                    // Exposure information
                    ("{Exif}ExposureTime" as String, "exposureTime"),
                    ("{Exif}FNumber" as String, "fNumber"),
                    ("{Exif}ExposureProgram" as String, "exposureProgram"),
                    ("{Exif}ISOSpeedRatings" as String, "isoSpeedRatings"),
                    ("{Exif}ShutterSpeedValue" as String, "shutterSpeed"),
                    ("{Exif}ApertureValue" as String, "aperture"),
                    ("{Exif}BrightnessValue" as String, "brightness"),
                    ("{Exif}ExposureBiasValue" as String, "exposureBias"),
                    ("{Exif}MeteringMode" as String, "meteringMode"),
                    ("{Exif}Flash" as String, "flash"),
                    
                    // Lens information
                    ("{Exif}FocalLength" as String, "focalLength"),
                    ("{Exif}FocalLenIn35mmFilm" as String, "focalLengthIn35mm"),
                    ("{Exif}LensModel" as String, "lensModel"),
                    ("{Exif}LensMake" as String, "lensMake"),
                    ("{Exif}LensSpecification" as String, "lensSpecification"),
                    
                    // Scene information
                    ("{Exif}SceneType" as String, "sceneType"),
                    ("{Exif}SceneCaptureType" as String, "sceneCaptureType"),
                    ("{Exif}WhiteBalance" as String, "whiteBalance"),
                    ("{Exif}DigitalZoomRatio" as String, "digitalZoomRatio"),
                    ("{Exif}Contrast" as String, "contrast"),
                    ("{Exif}Saturation" as String, "saturation"),
                    ("{Exif}Sharpness" as String, "sharpness"),
                    ("{Exif}SubjectDistRange" as String, "subjectDistanceRange"),
                    
                    // Image information
                    ("{Exif}ColorSpace" as String, "colorSpace"),
                    ("{Exif}ComponentsConfiguration" as String, "componentsConfiguration"),
                    ("{Exif}CompressedBitsPerPixel" as String, "compressedBitsPerPixel"),
                    ("{Exif}PixelXDimension" as String, "pixelXDimension"),
                    ("{Exif}PixelYDimension" as String, "pixelYDimension"),
                    
                    // Other information
                    ("{Exif}UserComment" as String, "userComment"),
                    ("{Exif}ImageUniqueID" as String, "imageUniqueID")
                ]
                
                for (exifKey, mappedKey) in commonExifProps {
                    if let value = exifDict[exifKey] {
                        // Special handling for specific EXIF values
                        if exifKey == "{Exif}ExposureTime" as String {
                            // Format exposure time as fraction if it's a small number
                            if let exposureTime = value as? Double, exposureTime < 1.0 {
                                let fraction = formatFraction(exposureTime)
                                items.append(MetadataItem(
                                    key: mappedKey,
                                    value: "\(fraction) sec",
                                    category: .image,
                                    valueType: .string
                                ))
                                continue
                            }
                        }
                        
                        // Format dates properly
                        if exifKey == "{Exif}DateTimeOriginal" as String || 
                           exifKey == "{Exif}DateTimeDigitized" as String {
                            if let dateString = value as? String {
                                // EXIF dates are in format: "YYYY:MM:DD HH:MM:SS"
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                                if let date = formatter.date(from: dateString) {
                                    items.append(MetadataItem(
                                        key: mappedKey,
                                        value: date,
                                        category: .image,
                                        valueType: .date
                                    ))
                                    continue
                                }
                            }
                        }
                        
                        // Determine value type
                        let valueType = MetadataValueType.detectType(of: value)
                        
                        items.append(MetadataItem(
                            key: mappedKey,
                            value: value,
                            category: .image,
                            valueType: valueType
                        ))
                    }
                }
                
                // Add any other EXIF properties not explicitly handled above
                for (key, value) in exifDict {
                    // Skip properties we already processed
                    if commonExifProps.contains(where: { $0.0 == key }) {
                        continue
                    }
                    
                    // Format the key
                    let formattedKey = key
                        .replacingOccurrences(of: "{", with: "")
                        .replacingOccurrences(of: "}", with: "")
                        .replacingOccurrences(of: "{Exif}", with: "")
                    
                    // Determine value type
                    let valueType = MetadataValueType.detectType(of: value)
                    
                    items.append(MetadataItem(
                        key: "exif" + formattedKey,
                        value: value,
                        category: .image,
                        valueType: valueType
                    ))
                }
            }
        }
        
        return items
    }
    
    /// Extract IPTC data from an image
    /// - Parameters:
    ///   - imageSource: The CGImageSource to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for IPTC data
    private func extractIPTCData(_ imageSource: CGImageSource, file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get the image properties dictionary
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            // Get IPTC data if available
            if let iptcDict = properties["{IPTC}" as String] as? [String: Any] {
                // Process common IPTC properties
                let commonIPTCProps = [
                    // Creator and copyright information
                    ("{IPTC}Creator" as String, "creator"),
                    ("{IPTC}CreatorContactInfo" as String, "creatorContactInfo"),
                    ("{IPTC}CopyrightNotice" as String, "copyrightNotice"),
                    ("{IPTC}RightsUsageTerms" as String, "rightsUsageTerms"),
                    
                    // Content description
                    ("{IPTC}Headline" as String, "headline"),
                    ("{IPTC}Caption" as String, "caption"),
                    ("{IPTC}Description" as String, "description"),
                    ("{IPTC}Keywords" as String, "keywords"),
                    
                    // Location information
                    ("{IPTC}CountryPrimaryLocationName" as String, "country"),
                    ("{IPTC}ProvinceState" as String, "provinceState"),
                    ("{IPTC}City" as String, "city"),
                    ("{IPTC}Location" as String, "location"),
                    
                    // Date information
                    ("{IPTC}DateCreated" as String, "dateCreated"),
                    ("{IPTC}TimeCreated" as String, "timeCreated"),
                    ("{IPTC}DigitalCreationDate" as String, "digitalCreationDate"),
                    ("{IPTC}DigitalCreationTime" as String, "digitalCreationTime"),
                    
                    // Other information
                    ("{IPTC}Source" as String, "source"),
                    ("{IPTC}Credit" as String, "credit"),
                    ("{IPTC}ObjectName" as String, "objectName")
                ]
                
                for (iptcKey, mappedKey) in commonIPTCProps {
                    if let value = iptcDict[iptcKey] {
                        // Special handling for IPTC dates
                        if iptcKey == "{IPTC}DateCreated" as String {
                            if let dateString = value as? String {
                                // IPTC dates are in format: "YYYYMMDD"
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyyMMdd"
                                if let date = formatter.date(from: dateString) {
                                    // If we also have time, we'll combine them later
                                    let dateOnly = Calendar.current.startOfDay(for: date)
                                    items.append(MetadataItem(
                                        key: mappedKey,
                                        value: dateOnly,
                                        category: .image,
                                        valueType: .date
                                    ))
                                    continue
                                }
                            }
                        }
                        
                        // Handle keywords (array of strings)
                        if iptcKey == "{IPTC}Keywords" as String {
                            if let keywords = value as? [String] {
                                items.append(MetadataItem(
                                    key: mappedKey,
                                    value: keywords.joined(separator: ", "),
                                    category: .image,
                                    valueType: .string
                                ))
                                continue
                            }
                        }
                        
                        // Determine value type
                        let valueType = MetadataValueType.detectType(of: value)
                        
                        items.append(MetadataItem(
                            key: mappedKey,
                            value: value,
                            category: .image,
                            valueType: valueType
                        ))
                    }
                }
                
                // Combine date and time if both exist
                if let dateString = iptcDict["{IPTC}DateCreated" as String] as? String,
                   let timeString = iptcDict["{IPTC}TimeCreated" as String] as? String {
                    
                    // IPTC time is in format: "HHMMSS±HHMM" or just "HHMMSS"
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd"
                    
                    if let date = dateFormatter.date(from: dateString) {
                        // Try to parse the time
                        let timeFormatter = DateFormatter()
                        timeFormatter.dateFormat = "HHmmss"
                        
                        if let time = timeFormatter.date(from: String(timeString.prefix(6))) {
                            let calendar = Calendar.current
                            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
                            
                            // Create a combined date
                            var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                            dateComponents.hour = timeComponents.hour
                            dateComponents.minute = timeComponents.minute
                            dateComponents.second = timeComponents.second
                            
                            if let combinedDate = calendar.date(from: dateComponents) {
                                items.append(MetadataItem(
                                    key: "creationDateTime",
                                    value: combinedDate,
                                    category: .image,
                                    valueType: .date
                                ))
                            }
                        }
                    }
                }
                
                // Add any other IPTC properties not explicitly handled above
                for (key, value) in iptcDict {
                    // Skip properties we already processed
                    if commonIPTCProps.contains(where: { $0.0 == key }) {
                        continue
                    }
                    
                    // Format the key
                    let formattedKey = key
                        .replacingOccurrences(of: "{", with: "")
                        .replacingOccurrences(of: "}", with: "")
                        .replacingOccurrences(of: "{IPTC}", with: "")
                    
                    // Determine value type
                    let valueType = MetadataValueType.detectType(of: value)
                    
                    items.append(MetadataItem(
                        key: "iptc" + formattedKey,
                        value: value,
                        category: .image,
                        valueType: valueType
                    ))
                }
            }
        }
        
        return items
    }
    
    /// Extract GPS data from an image
    /// - Parameters:
    ///   - imageSource: The CGImageSource to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for GPS data
    private func extractGPSData(_ imageSource: CGImageSource, file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get the image properties dictionary
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            // Get GPS data if available
            if let gpsDict = properties["{GPS}" as String] as? [String: Any] {
                // Extract latitude and longitude
                var latitude: Double?
                var longitude: Double?
                var altitude: Double?
                
                if let latRef = gpsDict["{GPS}LatitudeRef" as String] as? String,
                   let latValue = gpsDict["{GPS}Latitude" as String] as? Double {
                    latitude = latValue * (latRef == "N" ? 1 : -1)
                }
                
                if let longRef = gpsDict["{GPS}LongitudeRef" as String] as? String,
                   let longValue = gpsDict["{GPS}Longitude" as String] as? Double {
                    longitude = longValue * (longRef == "E" ? 1 : -1)
                }
                
                if let altRef = gpsDict["{GPS}AltitudeRef" as String] as? Int,
                   let altValue = gpsDict["{GPS}Altitude" as String] as? Double {
                    altitude = altValue * (altRef == 0 ? 1 : -1) // 0 = above sea level, 1 = below sea level
                }
                
                // Add individual coordinates
                if let lat = latitude {
                    items.append(MetadataItem(
                        key: "latitude",
                        value: lat,
                        category: .image,
                        valueType: .coordinate
                    ))
                }
                
                if let long = longitude {
                    items.append(MetadataItem(
                        key: "longitude",
                        value: long,
                        category: .image,
                        valueType: .coordinate
                    ))
                }
                
                if let alt = altitude {
                    items.append(MetadataItem(
                        key: "altitude",
                        value: alt,
                        category: .image,
                        valueType: .number
                    ))
                }
                
                // Add combined location
                if let lat = latitude, let long = longitude {
                    // Format for display
                    let latDirection = lat >= 0 ? "N" : "S"
                    let longDirection = long >= 0 ? "E" : "W"
                    let latDegrees = abs(lat)
                    let longDegrees = abs(long)
                    
                    let formattedLocation = String(format: "%.6f° %@, %.6f° %@",
                                                  latDegrees, latDirection,
                                                  longDegrees, longDirection)
                    
                    items.append(MetadataItem(
                        key: "gpsCoordinates",
                        value: formattedLocation,
                        category: .image,
                        valueType: .string
                    ))
                }
                
                // Process other GPS properties
                let commonGPSProps = [
                    ("{GPS}TimeStamp" as String, "gpsTimeStamp"),
                    ("{GPS}DateStamp" as String, "gpsDateStamp"),
                    ("{GPS}Speed" as String, "gpsSpeed"),
                    ("{GPS}SpeedRef" as String, "gpsSpeedRef"),
                    ("{GPS}Track" as String, "gpsTrack"),
                    ("{GPS}TrackRef" as String, "gpsTrackRef"),
                    ("{GPS}ImgDirection" as String, "gpsImgDirection"),
                    ("{GPS}ImgDirectionRef" as String, "gpsImgDirectionRef"),
                    ("{GPS}DestLatitude" as String, "gpsDestLatitude"),
                    ("{GPS}DestLongitude" as String, "gpsDestLongitude"),
                    ("{GPS}DestBearing" as String, "gpsDestBearing"),
                    ("{GPS}DestDistance" as String, "gpsDestDistance"),
                    ("{GPS}ProcessingMethod" as String, "gpsProcessingMethod"),
                    ("{GPS}AreaInformation" as String, "gpsAreaInformation"),
                    ("{GPS}Differental" as String, "gpsDifferental"),
                    ("{GPS}HPositioningError" as String, "gpsHPositioningError")
                ]
                
                for (gpsKey, mappedKey) in commonGPSProps {
                    if let value = gpsDict[gpsKey] {
                        // Special handling for GPS dates/times
                        if gpsKey == "{GPS}DateStamp" as String {
                            if let dateString = value as? String {
                                // GPS dates are in format: "YYYY:MM:DD"
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy:MM:dd"
                                if let date = formatter.date(from: dateString) {
                                    items.append(MetadataItem(
                                        key: mappedKey,
                                        value: date,
                                        category: .image,
                                        valueType: .date
                                    ))
                                    continue
                                }
                            }
                        }
                        
                        // Determine value type
                        let valueType = MetadataValueType.detectType(of: value)
                        
                        items.append(MetadataItem(
                            key: mappedKey,
                            value: value,
                            category: .image,
                            valueType: valueType
                        ))
                    }
                }
                
                // Add any other GPS properties not explicitly handled above
                for (key, value) in gpsDict {
                    // Skip properties we already processed
                    if key == "{GPS}Latitude" as String ||
                       key == "{GPS}LatitudeRef" as String ||
                       key == "{GPS}Longitude" as String ||
                       key == "{GPS}LongitudeRef" as String ||
                       key == "{GPS}Altitude" as String ||
                       key == "{GPS}AltitudeRef" as String ||
                       commonGPSProps.contains(where: { $0.0 == key }) {
                        continue
                    }
                    
                    // Format the key
                    let formattedKey = key
                        .replacingOccurrences(of: "{", with: "")
                        .replacingOccurrences(of: "}", with: "")
                        .replacingOccurrences(of: "{GPS}", with: "")
                    
                    // Determine value type
                    let valueType = MetadataValueType.detectType(of: value)
                    
                    items.append(MetadataItem(
                        key: "gps" + formattedKey,
                        value: value,
                        category: .image,
                        valueType: valueType
                    ))
                }
            }
        }
        
        return items
    }
    
    /// Extract color profile data from an image
    /// - Parameters:
    ///   - imageSource: The CGImageSource to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for color profile data
    private func extractColorProfileData(_ imageSource: CGImageSource, file: FileReference) throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get the image properties dictionary
        if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            // Check for color profile information
            let profileNames = [
                kCGImagePropertyProfileName as String: "colorProfileName",
                "{ExifAux}ProfileName" as String: "auxProfileName"
            ]
            
            for (key, mappedKey) in profileNames {
                if let profileName = properties[key] as? String {
                    items.append(MetadataItem(
                        key: mappedKey,
                        value: profileName,
                        category: .image,
                        valueType: .string
                    ))
                }
            }
            
            // Get color model
            if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
                items.append(MetadataItem(
                    key: "colorModel",
                    value: colorModel,
                    category: .image,
                    valueType: .string
                ))
                
                // Add additional color model details if available
                if colorModel == "RGB" {
                    if let hasAlpha = properties[kCGImagePropertyHasAlpha as String] as? Bool {
                        let colorType = hasAlpha ? "RGBA" : "RGB"
                        items.append(MetadataItem(
                            key: "colorType",
                            value: colorType,
                            category: .image,
                            valueType: .string
                        ))
                    }
                }
            }
            
            // Add generic profile info since we can't reliably extract it
            items.append(MetadataItem(
                key: "embeddedProfile",
                value: "Color Profile Information",
                category: .image,
                valueType: .string
            ))
        }
        
        return items
    }
    
    /// Format a decimal as a fraction string (e.g., 0.5 -> "1/2")
    /// - Parameter decimal: The decimal to format
    /// - Returns: A string representation of the fraction
    private func formatFraction(_ decimal: Double) -> String {
        // Handle special cases
        if decimal == 0 {
            return "0"
        }
        
        if decimal == 1 {
            return "1"
        }
        
        // For small exposure times, use standard fractions
        if decimal <= 0.0001 {
            return "1/10000"
        } else if decimal <= 0.00013 {
            return "1/8000"
        } else if decimal <= 0.00017 {
            return "1/6000"
        } else if decimal <= 0.00025 {
            return "1/4000"
        } else if decimal <= 0.0003125 {
            return "1/3200"
        } else if decimal <= 0.0004 {
            return "1/2500"
        } else if decimal <= 0.0005 {
            return "1/2000"
        } else if decimal <= 0.000625 {
            return "1/1600"
        } else if decimal <= 0.0008 {
            return "1/1250"
        } else if decimal <= 0.001 {
            return "1/1000"
        } else if decimal <= 0.00125 {
            return "1/800"
        } else if decimal <= 0.0016667 {
            return "1/600"
        } else if decimal <= 0.002 {
            return "1/500"
        } else if decimal <= 0.0025 {
            return "1/400"
        } else if decimal <= 0.00333 {
            return "1/300"
        } else if decimal <= 0.004 {
            return "1/250"
        } else if decimal <= 0.005 {
            return "1/200"
        } else if decimal <= 0.00625 {
            return "1/160"
        } else if decimal <= 0.00769 {
            return "1/130"
        } else if decimal <= 0.008 {
            return "1/125"
        } else if decimal <= 0.01 {
            return "1/100"
        } else if decimal <= 0.0125 {
            return "1/80"
        } else if decimal <= 0.01667 {
            return "1/60"
        } else if decimal <= 0.02 {
            return "1/50"
        } else if decimal <= 0.025 {
            return "1/40"
        } else if decimal <= 0.03333 {
            return "1/30"
        } else if decimal <= 0.04 {
            return "1/25"
        } else if decimal <= 0.05 {
            return "1/20"
        } else if decimal <= 0.0625 {
            return "1/16"
        } else if decimal <= 0.07692 {
            return "1/13"
        } else if decimal <= 0.08333 {
            return "1/12"
        } else if decimal <= 0.1 {
            return "1/10"
        } else if decimal <= 0.125 {
            return "1/8"
        } else if decimal <= 0.16667 {
            return "1/6"
        } else if decimal <= 0.2 {
            return "1/5"
        } else if decimal <= 0.25 {
            return "1/4"
        } else if decimal <= 0.33333 {
            return "1/3"
        } else if decimal <= 0.5 {
            return "1/2"
        }
        
        // For values greater than 0.5, use a different approach
        // Find a reasonable denominator
        let maxDenominator = 100
        var bestNumerator = 1
        var bestDenominator = 1
        var bestDiff = abs(decimal - 1.0)
        
        for denominator in 1...maxDenominator {
            let numerator = Int(round(decimal * Double(denominator)))
            if numerator > 0 {
                let diff = abs(decimal - Double(numerator) / Double(denominator))
                if diff < bestDiff {
                    bestDiff = diff
                    bestNumerator = numerator
                    bestDenominator = denominator
                }
            }
        }
        
        // Simplify the fraction
        let gcd = greatestCommonDivisor(bestNumerator, bestDenominator)
        let simplifiedNumerator = bestNumerator / gcd
        let simplifiedDenominator = bestDenominator / gcd
        
        if simplifiedDenominator == 1 {
            return "\(simplifiedNumerator)"
        } else {
            return "\(simplifiedNumerator)/\(simplifiedDenominator)"
        }
    }
    
    /// Calculate the greatest common divisor of two integers
    /// - Parameters:
    ///   - a: First integer
    ///   - b: Second integer
    /// - Returns: The GCD of a and b
    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var x = a
        var y = b
        while y != 0 {
            let temp = y
            y = x % y
            x = temp
        }
        return x
    }
}
