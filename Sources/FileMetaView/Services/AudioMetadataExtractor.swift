import Foundation
import UniformTypeIdentifiers
import AVFoundation
import os.log

/// A metadata extractor specialized for audio files (MP3, M4A, WAV, etc.)
class AudioMetadataExtractor: MetadataExtractor {
    /// Logger for this extractor
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "AudioMetadataExtractor")
    
    /// Audio UTI types this extractor can handle
    private let supportedAudioTypes = [
        UTType.audio.identifier,
        UTType.mp3.identifier,
        UTType.wav.identifier,
        "com.apple.m4a-audio",       // M4A
        "public.aifc-audio",         // AIFC
        "public.aiff-audio",         // AIFF
        "org.xiph.flac",             // FLAC
        "org.xiph.ogg",              // OGG
        "com.apple.coreaudio-format" // Core Audio Format
    ]
    
    /// Audio file extensions this extractor can handle
    private let supportedAudioExtensions = [
        "mp3", "m4a", "wav", "wave", "aac", "flac", "ogg", 
        "wma", "aiff", "aif", "aifc", "caf", "opus"
    ]
    
    /// Initialize a new AudioMetadataExtractor
    init() {}
    
    /// Extract metadata from an audio file
    /// - Parameter file: The file reference to extract metadata from
    /// - Returns: An array of metadata items
    /// - Throws: FileAccessError if extraction fails
    func extractMetadata(from file: FileReference) async throws -> [MetadataItem] {
        logger.info("Extracting audio metadata for file: \(file.url.lastPathComponent)")
        
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
            // Create asset from URL
            let asset = AVAsset(url: file.url)
            
            // Extract basic audio properties
            let basicItems = try await extractBasicAudioProperties(asset, file: file)
            items.append(contentsOf: basicItems)
            
            // Extract format metadata
            let formatItems = try await extractAudioFormatData(asset, file: file)
            items.append(contentsOf: formatItems)
            
            // Extract ID3/metadata tags
            let tagItems = try await extractAudioTags(asset, file: file)
            items.append(contentsOf: tagItems)
            
            // Limit the number of items and return
            return limitItems(items)
        } catch let error as MetadataExtractionError {
            logger.error("Error extracting audio metadata: \(error)")
            switch error {
            case .unsupportedFileType(let message):
                throw FileAccessError.unsupportedFileType(file.url, message)
            case .operationCancelled(let message):
                throw FileAccessError.operationCancelled(message)
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
                throw FileAccessError.timeout(file.url, "Audio metadata extraction timed out after \(Int(seconds)) seconds")
            }
        } catch {
            logger.error("Error extracting audio metadata: \(error.localizedDescription)")
            throw handleExtractionError(error, file: file, context: "Audio metadata extraction")
        }
    }
    
    /// Check if this extractor can handle a specific file type
    /// - Parameters:
    ///   - fileType: The UTI string of the file
    ///   - fileExtension: Optional file extension as fallback
    /// - Returns: Boolean indicating if this extractor can handle the file type
    func canHandle(fileType: String, fileExtension: String?) -> Bool {
        // Check by UTI conformance to audio type
        if utiConforms(fileType, to: UTType.audio.identifier) {
            return true
        }
        
        // Check by specific UTI types
        if supportedAudioTypes.contains(fileType) {
            return true
        }
        
        // Check by extension if UTI checks failed
        if let ext = fileExtension?.lowercased(), supportedAudioExtensions.contains(ext) {
            return true
        }
        
        return false
    }
    
    /// Name of this extractor for identification
    /// - Returns: String identifier for this extractor type
    func extractorName() -> String {
        return "Audio Metadata Extractor"
    }
    
    /// Description of the types of metadata this extractor provides
    /// - Returns: Human-readable description
    func extractorDescription() -> String {
        return "Extracts metadata from audio files including ID3 tags, format information, and technical details"
    }
    
    /// Categories of metadata this extractor can provide
    /// - Returns: Array of metadata categories this extractor handles
    func providedCategories() -> [MetadataCategory] {
        return [.audio]
    }
    
    /// Priority of this extractor relative to others
    /// - Returns: Priority value (higher values indicate higher priority)
    func priority() -> Int {
        // Audio metadata extractor has high priority for audio files
        return 8
    }
    
    /// Performance impact rating of this extractor (1-10)
    /// - Returns: Rating where higher values indicate more resource-intensive processing
    func performanceImpact() -> Int {
        // Audio metadata extraction is moderately resource-intensive
        return 6
    }
    
    /// Recommended file size limit for this extractor
    /// - Returns: Maximum recommended file size in bytes, or nil for no limit
    func recommendedFileSizeLimit() -> Int64? {
        // For audio files, reasonable limit is 500MB
        return 500 * 1024 * 1024
    }
    
    // MARK: - Private Methods
    
    /// Extract basic audio properties (format, duration, etc.)
    /// - Parameters:
    ///   - asset: The AVAsset to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for basic audio properties
    private func extractBasicAudioProperties(_ asset: AVAsset, file: FileReference) async throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get duration
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        items.append(MetadataItem(
            key: "duration",
            value: durationInSeconds,
            category: .audio,
            valueType: .duration
        ))
        
        // Get created/modified dates from the file attributes
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.url.path) {
            if let creationDate = attributes[.creationDate] as? Date {
                items.append(MetadataItem(
                    key: "creationDate",
                    value: creationDate,
                    category: .audio,
                    valueType: .date
                ))
            }
            
            if let modificationDate = attributes[.modificationDate] as? Date {
                items.append(MetadataItem(
                    key: "modificationDate",
                    value: modificationDate,
                    category: .audio,
                    valueType: .date
                ))
            }
            
            if let fileSize = attributes[.size] as? Int64 {
                items.append(MetadataItem(
                    key: "fileSize",
                    value: fileSize,
                    category: .audio,
                    valueType: .fileSize
                ))
            }
        }
        
        // Get file name and extension
        items.append(MetadataItem(
            key: "fileName",
            value: file.name,
            category: .audio,
            valueType: .string
        ))
        
        items.append(MetadataItem(
            key: "fileExtension",
            value: file.fileExtension,
            category: .audio,
            valueType: .string
        ))
        
        return items
    }
    
    /// Extract audio format data (codec, sample rate, etc.)
    /// - Parameters:
    ///   - asset: The AVAsset to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for audio format data
    private func extractAudioFormatData(_ asset: AVAsset, file: FileReference) async throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        guard let audioTrack = audioTracks.first else {
            throw MetadataExtractionError.metadataParsingFailed("No audio track found")
        }
        
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        
        if let formatDescription = formatDescriptions.first {
            // Get format information from CMAudioFormatDescription
            let formatPtr = formatDescription as CMAudioFormatDescription
            
            if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatPtr) {
                // Sample rate
                let sampleRate = streamBasicDescription.pointee.mSampleRate
                items.append(MetadataItem(
                    key: "sampleRate",
                    value: sampleRate,
                    category: .audio,
                    valueType: .number
                ))
                
                // Add formatted sample rate
                if sampleRate >= 1000 {
                    items.append(MetadataItem(
                        key: "sampleRateFormatted",
                        value: String(format: "%.1f kHz", sampleRate / 1000),
                        category: .audio,
                        valueType: .string
                    ))
                }
                
                // Number of channels
                let channelCount = Int(streamBasicDescription.pointee.mChannelsPerFrame)
                items.append(MetadataItem(
                    key: "channels",
                    value: channelCount,
                    category: .audio,
                    valueType: .number
                ))
                
                // Channel configuration name
                let channelConfigName: String
                switch channelCount {
                case 1: channelConfigName = "Mono"
                case 2: channelConfigName = "Stereo"
                case 6: channelConfigName = "5.1 Surround"
                case 8: channelConfigName = "7.1 Surround"
                default: channelConfigName = "\(channelCount) channels"
                }
                
                items.append(MetadataItem(
                    key: "channelConfiguration",
                    value: channelConfigName,
                    category: .audio,
                    valueType: .string
                ))
                
                // Bits per channel
                let bitsPerChannel = Int(streamBasicDescription.pointee.mBitsPerChannel)
                if bitsPerChannel > 0 {
                    items.append(MetadataItem(
                        key: "bitsPerChannel",
                        value: bitsPerChannel,
                        category: .audio,
                        valueType: .number
                    ))
                }
                
                // Bytes per frame
                let bytesPerFrame = Int(streamBasicDescription.pointee.mBytesPerFrame)
                if bytesPerFrame > 0 {
                    items.append(MetadataItem(
                        key: "bytesPerFrame",
                        value: bytesPerFrame,
                        category: .audio,
                        valueType: .number
                    ))
                }
                
                // Format flags
                let formatFlags = Int(streamBasicDescription.pointee.mFormatFlags)
                if formatFlags > 0 {
                    items.append(MetadataItem(
                        key: "formatFlags",
                        value: formatFlags,
                        category: .audio,
                        valueType: .number
                    ))
                }
            }
            
            // Format information
            var formatIDString = ""
            var formatName = ""
            
            // Format description
            let formatID = CMFormatDescriptionGetMediaSubType(formatDescription)
            // Convert format ID to integer, but we'll use the 4-char code directly
            _ = Int(formatID)
            
            // Convert 4-char code to string
            let formatIDChars: [CChar] = [
                CChar((formatID >> 24) & 0xFF),
                CChar((formatID >> 16) & 0xFF),
                CChar((formatID >> 8) & 0xFF),
                CChar(formatID & 0xFF),
                0
            ]
            
            if let formatIDCString = formatIDChars.withUnsafeBufferPointer({ $0.baseAddress }) {
                formatIDString = String(cString: formatIDCString)
            }
            
            // Get format name based on format ID
            switch formatIDString {
            case "mp3 ", "mp3":
                formatName = "MP3"
            case "aac ", "aac":
                formatName = "AAC"
            case "alac":
                formatName = "Apple Lossless (ALAC)"
            case "flac":
                formatName = "FLAC"
            case "opus":
                formatName = "Opus"
            case "lpcm":
                formatName = "Linear PCM"
            case "ima4":
                formatName = "IMA/ADPCM"
            case "ulaw":
                formatName = "μ-Law"
            case "alaw":
                formatName = "A-Law"
            default:
                formatName = formatIDString
            }
            
            items.append(MetadataItem(
                key: "audioFormat",
                value: formatName,
                category: .audio,
                valueType: .string
            ))
            
            items.append(MetadataItem(
                key: "formatID",
                value: formatIDString,
                category: .audio,
                valueType: .string
            ))
        }
        
        // Estimated bitrate
        let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
        if estimatedDataRate > 0 {
            items.append(MetadataItem(
                key: "bitrate",
                value: estimatedDataRate,
                category: .audio,
                valueType: .number
            ))
            
            // Add formatted bitrate
            if estimatedDataRate >= 1000 {
                items.append(MetadataItem(
                    key: "bitrateFormatted",
                    value: String(format: "%.0f kbps", estimatedDataRate / 1000),
                    category: .audio,
                    valueType: .string
                ))
            } else {
                items.append(MetadataItem(
                    key: "bitrateFormatted",
                    value: String(format: "%.0f bps", estimatedDataRate),
                    category: .audio,
                    valueType: .string
                ))
            }
        }
        
        // Preferred volume
        let preferredVolume = try await audioTrack.load(.preferredVolume)
        if preferredVolume != 1.0 {
            items.append(MetadataItem(
                key: "preferredVolume",
                value: preferredVolume,
                category: .audio,
                valueType: .number
            ))
        }
        
        // Natural timeScale
        let naturalTimeScale = try await audioTrack.load(.naturalTimeScale)
        if naturalTimeScale > 0 {
            items.append(MetadataItem(
                key: "naturalTimeScale",
                value: naturalTimeScale,
                category: .audio,
                valueType: .number
            ))
        }
        
        return items
    }
    
    /// Extract audio tag data (ID3, iTunes metadata, etc.)
    /// - Parameters:
    ///   - asset: The AVAsset to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for audio tag data
    private func extractAudioTags(_ asset: AVAsset, file: FileReference) async throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Create a dictionary to map common metadata keys to their display names
        let commonMetadataMapping: [(String, String, MetadataValueType)] = [
            // Common keys
            (AVMetadataKey.commonKeyTitle.rawValue, "title", .string),
            (AVMetadataKey.commonKeyAlbumName.rawValue, "album", .string),
            (AVMetadataKey.commonKeyArtist.rawValue, "artist", .string),
            (AVMetadataKey.commonKeyCreator.rawValue, "creator", .string),
            (AVMetadataKey.commonKeyAuthor.rawValue, "author", .string),
            (AVMetadataKey.commonKeyCreationDate.rawValue, "creationDate", .date),
            (AVMetadataKey.commonKeyCopyrights.rawValue, "copyright", .string),
            (AVMetadataKey.commonKeyDescription.rawValue, "description", .string),
            (AVMetadataKey.commonKeyType.rawValue, "type", .string),
            (AVMetadataKey.commonKeySubject.rawValue, "subject", .string),
            
            // ID3 keys - using string literals since some constants don't exist directly
            ("TIT2", "titleDescription", .string),
            ("TALB", "albumTitle", .string),
            ("TPE1", "performer", .string),
            ("TPE2", "band", .string),
            ("TCOM", "composer", .string),
            ("TCON", "contentType", .string),
            ("TPE3", "conductor", .string),
            ("TOPE", "originalArtist", .string),
            ("TEXT", "lyricist", .string),
            ("TSOA", "albumSortOrder", .string),
            ("TSOT", "titleSortOrder", .string),
            ("TSOP", "artistSortOrder", .string),
            ("TPOS", "partOfSet", .string),
            ("TRCK", "trackNumber", .number),
            ("TIT3", "subtitle", .string),
            ("TMED", "mediaType", .string),
            ("TLEN", "length", .string),
            ("TBPM", "beatsPerMinute", .number),
            ("TKEY", "initialKey", .string),
            ("TDAT", "date", .string),
            ("TYER", "year", .string),
            ("TORY", "originalReleaseYear", .string),
            ("TPUB", "publisher", .string),
            ("TOWN", "fileOwner", .string),
            ("TENC", "encodedBy", .string),
            ("USLT", "lyrics", .string),
            ("COMM", "comments", .string),
            ("TCOP", "copyrightMessage", .string),
            ("WOAF", "fileWebpage", .url),
            ("WOAR", "artistWebpage", .url),
            ("WOAS", "sourceWebpage", .url),
            ("WORS", "radioStationWebpage", .url),
            ("WPAY", "payment", .string),
            ("WPUB", "publisherWebpage", .url)
        ]
        
        // Get all metadata
        let metadata = try await asset.load(.metadata)
        
        for metadataItem in metadata {
            // Get key and value
            let identifier = metadataItem.identifier
            let commonKey = metadataItem.commonKey
            
            // Get key string - try common key first, then identifier, fallback to unknown
            let keyString = commonKey?.rawValue as? String ?? 
                            identifier?.rawValue as? String ?? "<unknown key>"
            
            // Get key space
            let keySpace = metadataItem.keySpace
            
            // Skip iTunes-specific keys starting with "com.apple.iTunes"
            // We'll handle them separately through common keys
            if let keySpaceString = keySpace?.rawValue as? String,
               keySpaceString == "itsk" && keyString.starts(with: "com.apple.iTunes") {
                continue
            }
            
            // Skip artwork as it's handled separately
            if commonKey == AVMetadataKey.commonKeyArtwork {
                continue
            }
            
            // Convert metadata value to appropriate Swift type
            guard let value = metadataItem.value else {
                continue
            }
            
            // Find mapping for this key
            var displayKey = keyString
            var valueType: MetadataValueType = .string
            
            for (metadataKey, mappedKey, mappedType) in commonMetadataMapping {
                if keyString == metadataKey {
                    displayKey = mappedKey
                    valueType = mappedType
                    break
                }
            }
            
            // Clean up the key for display
            if displayKey == keyString && keyString.contains(":") {
                displayKey = keyString.components(separatedBy: ":").last ?? keyString
            }
            
            // Special handling for dates
            if valueType == .date, let dateString = value as? String {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                if let date = dateFormatter.date(from: dateString) {
                    items.append(MetadataItem(
                        key: displayKey,
                        value: date,
                        category: .audio,
                        valueType: .date
                    ))
                    continue
                } else if let year = Int(dateString), year > 1900 && year < 2100 {
                    // Handle year-only dates
                    dateFormatter.dateFormat = "yyyy"
                    if let date = dateFormatter.date(from: dateString) {
                        items.append(MetadataItem(
                            key: displayKey,
                            value: date,
                            category: .audio,
                            valueType: .date
                        ))
                        continue
                    }
                }
            }
            
            // Add the metadata item
            items.append(MetadataItem(
                key: displayKey,
                value: value,
                category: .audio,
                valueType: valueType
            ))
        }
        
        return items
    }
}
