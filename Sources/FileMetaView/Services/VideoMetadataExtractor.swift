import Foundation
import UniformTypeIdentifiers
import AVFoundation
import CoreMedia
import os.log

/// A metadata extractor specialized for video files (MP4, MOV, AVI, etc.)
class VideoMetadataExtractor: MetadataExtractor {
    /// Logger for this extractor
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "VideoMetadataExtractor")
    
    /// Video UTI types this extractor can handle
    private let supportedVideoTypes = [
        UTType.movie.identifier,
        UTType.video.identifier,
        UTType.mpeg.identifier,
        UTType.mpeg2Video.identifier,
        "public.mpeg-4",
        "com.apple.protected-mpeg-4-video",
        UTType.quickTimeMovie.identifier,
        UTType.avi.identifier,
        "com.microsoft.windows-media-wmv",    // WMV
        "com.adobe.flash.video",              // FLV
        "org.webmproject.webm",               // WebM
        "org.matroska.mkv",                   // MKV
        "public.3gpp",                        // 3GP
        "public.3gpp2"                        // 3GP2
    ]
    
    /// Video file extensions this extractor can handle
    private let supportedVideoExtensions = [
        "mp4", "mov", "avi", "wmv", "flv", "webm", "mkv", "3gp", "3g2", 
        "m4v", "mpg", "mpeg", "m2v", "ts", "mts", "vob", "ogv", "divx"
    ]
    
    /// Initialize a new VideoMetadataExtractor
    init() {}
    
    /// Extract metadata from a video file
    /// - Parameter file: The file reference to extract metadata from
    /// - Returns: An array of metadata items
    /// - Throws: FileAccessError if extraction fails
    func extractMetadata(from file: FileReference) async throws -> [MetadataItem] {
        logger.info("Extracting video metadata for file: \(file.url.lastPathComponent)")
        
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
            
            // Extract basic video properties
            let basicItems = try await extractBasicVideoProperties(asset, file: file)
            items.append(contentsOf: basicItems)
            
            // Extract video-specific information
            let videoItems = try await extractVideoTrackData(asset, file: file)
            items.append(contentsOf: videoItems)
            
            // Extract audio information from the video (if available)
            let audioItems = try await extractAudioTrackData(asset, file: file)
            items.append(contentsOf: audioItems)
            
            // Extract metadata tags
            let metadataItems = try await extractVideoMetadata(asset, file: file)
            items.append(contentsOf: metadataItems)
            
            // Limit the number of items and return
            return limitItems(items)
        } catch let error as MetadataExtractionError {
            logger.error("Error extracting video metadata: \(error)")
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
                throw FileAccessError.timeout(file.url, "Video metadata extraction timed out after \(Int(seconds)) seconds")
            }
        } catch {
            logger.error("Error extracting video metadata: \(error.localizedDescription)")
            throw handleExtractionError(error, file: file, context: "Video metadata extraction")
        }
    }
    
    /// Check if this extractor can handle a specific file type
    /// - Parameters:
    ///   - fileType: The UTI string of the file
    ///   - fileExtension: Optional file extension as fallback
    /// - Returns: Boolean indicating if this extractor can handle the file type
    func canHandle(fileType: String, fileExtension: String?) -> Bool {
        // Check by UTI conformance to movie/video type
        if utiConforms(fileType, to: UTType.movie.identifier) ||
           utiConforms(fileType, to: UTType.video.identifier) {
            return true
        }
        
        // Check by specific UTI types
        if supportedVideoTypes.contains(fileType) {
            return true
        }
        
        // Check by extension if UTI checks failed
        if let ext = fileExtension?.lowercased(), supportedVideoExtensions.contains(ext) {
            return true
        }
        
        return false
    }
    
    /// Name of this extractor for identification
    /// - Returns: String identifier for this extractor type
    func extractorName() -> String {
        return "Video Metadata Extractor"
    }
    
    /// Description of the types of metadata this extractor provides
    /// - Returns: Human-readable description
    func extractorDescription() -> String {
        return "Extracts metadata from video files including resolution, frame rate, codec information, and content details"
    }
    
    /// Categories of metadata this extractor can provide
    /// - Returns: Array of metadata categories this extractor handles
    func providedCategories() -> [MetadataCategory] {
        return [.video, .audio]
    }
    
    /// Priority of this extractor relative to others
    /// - Returns: Priority value (higher values indicate higher priority)
    func priority() -> Int {
        // Video metadata extractor has high priority for video files
        return 8
    }
    
    /// Performance impact rating of this extractor (1-10)
    /// - Returns: Rating where higher values indicate more resource-intensive processing
    func performanceImpact() -> Int {
        // Video metadata extraction is very resource-intensive
        return 9
    }
    
    /// Recommended file size limit for this extractor
    /// - Returns: Maximum recommended file size in bytes, or nil for no limit
    func recommendedFileSizeLimit() -> Int64? {
        // For video files, reasonable limit is 2GB
        return 2 * 1024 * 1024 * 1024
    }
    
    // MARK: - Private Methods
    
    /// Extract basic video properties (duration, file size, etc.)
    /// - Parameters:
    ///   - asset: The AVAsset to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for basic video properties
    private func extractBasicVideoProperties(_ asset: AVAsset, file: FileReference) async throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get duration
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        items.append(MetadataItem(
            key: "duration",
            value: durationInSeconds,
            category: .video,
            valueType: .duration
        ))
        
        // Format duration as HH:MM:SS
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        if let formattedDuration = formatter.string(from: durationInSeconds) {
            items.append(MetadataItem(
                key: "formattedDuration",
                value: formattedDuration,
                category: .video,
                valueType: .string
            ))
        }
        
        // Get created/modified dates from the file attributes
        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.url.path) {
            if let creationDate = attributes[.creationDate] as? Date {
                items.append(MetadataItem(
                    key: "creationDate",
                    value: creationDate,
                    category: .video,
                    valueType: .date
                ))
            }
            
            if let modificationDate = attributes[.modificationDate] as? Date {
                items.append(MetadataItem(
                    key: "modificationDate",
                    value: modificationDate,
                    category: .video,
                    valueType: .date
                ))
            }
            
            if let fileSize = attributes[.size] as? Int64 {
                items.append(MetadataItem(
                    key: "fileSize",
                    value: fileSize,
                    category: .video,
                    valueType: .fileSize
                ))
            }
        }
        
        // Get file name and extension
        items.append(MetadataItem(
            key: "fileName",
            value: file.name,
            category: .video,
            valueType: .string
        ))
        
        items.append(MetadataItem(
            key: "fileExtension",
            value: file.fileExtension,
            category: .video,
            valueType: .string
        ))
        
        // Get playable status
        let playable = try await asset.load(.isPlayable)
        if playable {
            items.append(MetadataItem(
                key: "isPlayable",
                value: true,
                category: .video,
                valueType: .boolean
            ))
        }
        
        // Check if video is protected content
        let protected = try await asset.load(.hasProtectedContent)
        if protected {
            items.append(MetadataItem(
                key: "hasProtectedContent",
                value: true,
                category: .video,
                valueType: .boolean
            ))
        }
        
        // Get container format
        let containerFormats = [
            "mov": "QuickTime Movie",
            "mp4": "MPEG-4",
            "m4v": "MPEG-4 Video",
            "avi": "Audio Video Interleave",
            "wmv": "Windows Media Video",
            "flv": "Flash Video",
            "webm": "WebM",
            "mkv": "Matroska Video",
            "3gp": "3GPP",
            "mpg": "MPEG",
            "mpeg": "MPEG",
            "vob": "DVD Video Object",
            "ogv": "Ogg Video"
        ]
        
        if let containerFormat = containerFormats[file.fileExtension.lowercased()] {
            items.append(MetadataItem(
                key: "containerFormat",
                value: containerFormat,
                category: .video,
                valueType: .string
            ))
        }
        
        return items
    }
    
    /// Extract video track data (resolution, frame rate, codec, etc.)
    /// - Parameters:
    ///   - asset: The AVAsset to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for video track data
    private func extractVideoTrackData(_ asset: AVAsset, file: FileReference) async throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        
        if videoTracks.isEmpty {
            throw MetadataExtractionError.metadataParsingFailed("No video track found")
        }
        
        // Number of video tracks
        items.append(MetadataItem(
            key: "videoTrackCount",
            value: videoTracks.count,
            category: .video,
            valueType: .number
        ))
        
        // Process primary video track
        let videoTrack = videoTracks[0]
        
        // Track ID
        let trackID = videoTrack.trackID
        items.append(MetadataItem(
            key: "videoTrackID",
            value: trackID,
            category: .video,
            valueType: .number
        ))
        
        // Video dimensions
        let dimensions = try await videoTrack.load(.naturalSize)
        items.append(MetadataItem(
            key: "width",
            value: dimensions.width,
            category: .video,
            valueType: .number
        ))
        
        items.append(MetadataItem(
            key: "height",
            value: dimensions.height,
            category: .video,
            valueType: .number
        ))
        
        items.append(MetadataItem(
            key: "resolution",
            value: "\(Int(dimensions.width)) × \(Int(dimensions.height))",
            category: .video,
            valueType: .string
        ))
        
        // Check for standard resolutions
        let resolutionName = getResolutionName(width: Int(dimensions.width), height: Int(dimensions.height))
        if !resolutionName.isEmpty {
            items.append(MetadataItem(
                key: "resolutionStandard",
                value: resolutionName,
                category: .video,
                valueType: .string
            ))
        }
        
        // Frame rate
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        items.append(MetadataItem(
            key: "frameRate",
            value: Float(nominalFrameRate),
            category: .video,
            valueType: .number
        ))
        
        // Format the frame rate (fixed to 2 decimal places if needed)
        let formattedFrameRate: String
        if nominalFrameRate.truncatingRemainder(dividingBy: 1) == 0 {
            formattedFrameRate = "\(Int(nominalFrameRate)) fps"
        } else {
            formattedFrameRate = String(format: "%.2f fps", nominalFrameRate)
        }
        
        items.append(MetadataItem(
            key: "formattedFrameRate",
            value: formattedFrameRate,
            category: .video,
            valueType: .string
        ))
        
        // Track orientation (transform)
        let transform = try await videoTrack.load(.preferredTransform)
        if !transform.isIdentity {
            let rotation = getRotationFromTransform(transform)
            items.append(MetadataItem(
                key: "rotation",
                value: rotation,
                category: .video,
                valueType: .number
            ))
            
            items.append(MetadataItem(
                key: "isRotated",
                value: rotation != 0,
                category: .video,
                valueType: .boolean
            ))
        }
        
        // Codec information
        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        
        if let formatDescription = formatDescriptions.first {
            // Format information
            var codecType = ""
            var codecName = ""
            
            // Format description
            let codecID = CMFormatDescriptionGetMediaSubType(formatDescription)
            
            // Convert 4-char code to string
            let codecIDChars: [CChar] = [
                CChar((codecID >> 24) & 0xFF),
                CChar((codecID >> 16) & 0xFF),
                CChar((codecID >> 8) & 0xFF),
                CChar(codecID & 0xFF),
                0
            ]
            
            if let codecIDCString = codecIDChars.withUnsafeBufferPointer({ $0.baseAddress }) {
                codecType = String(cString: codecIDCString)
            }
            
            // Get codec name based on format ID
            switch codecType {
            case "avc1", "H264":
                codecName = "H.264/AVC"
            case "hvc1", "HEVC":
                codecName = "H.265/HEVC"
            case "mp4v":
                codecName = "MPEG-4 Visual"
            case "mjpa", "mjpb":
                codecName = "Motion JPEG"
            case "dvh1", "dvhe":
                codecName = "Dolby Vision"
            case "av01":
                codecName = "AV1"
            case "vp09":
                codecName = "VP9"
            case "dvc ", "dvcp":
                codecName = "DV/DVCPRO"
            case "mp1v":
                codecName = "MPEG-1 Video"
            case "mp2v":
                codecName = "MPEG-2 Video"
            case "rpza":
                codecName = "Apple Video"
            case "SVQ1":
                codecName = "Sorenson Video 1"
            case "SVQ3":
                codecName = "Sorenson Video 3"
            case "VP31", "VP30":
                codecName = "VP3"
            case "rv30", "rv40":
                codecName = "RealVideo"
            default:
                codecName = codecType
            }
            
            items.append(MetadataItem(
                key: "videoCodec",
                value: codecName,
                category: .video,
                valueType: .string
            ))
            
            items.append(MetadataItem(
                key: "videoCodecType",
                value: codecType,
                category: .video,
                valueType: .string
            ))
            
            // Try to get more codec details
            let codecExtension = CMFormatDescriptionGetExtension(formatDescription, extensionKey: "SampleDescriptionExtensionAtoms" as CFString) as? NSDictionary
            
            if let codecExtension = codecExtension {
                for (key, value) in codecExtension {
                    if let key = key as? String {
                        items.append(MetadataItem(
                            key: "codecDetail" + key,
                            value: String(describing: value),
                            category: .video,
                            valueType: .string
                        ))
                    }
                }
            }
        }
        
        // Data rate
        let dataRate = try await videoTrack.load(.estimatedDataRate)
        if dataRate > 0 {
            items.append(MetadataItem(
                key: "videoBitrate",
                value: dataRate,
                category: .video,
                valueType: .number
            ))
            
            // Format bitrate
            if dataRate >= 1_000_000 {
                items.append(MetadataItem(
                    key: "videoBitrateFormatted",
                    value: String(format: "%.2f Mbps", dataRate / 1_000_000),
                    category: .video,
                    valueType: .string
                ))
            } else if dataRate >= 1000 {
                items.append(MetadataItem(
                    key: "videoBitrateFormatted",
                    value: String(format: "%.0f kbps", dataRate / 1000),
                    category: .video,
                    valueType: .string
                ))
            }
        }
        
        // Process information for other tracks if more than one
        if videoTracks.count > 1 {
            for (index, track) in videoTracks.dropFirst().enumerated() {
                // Track ID
                let trackID = track.trackID
                items.append(MetadataItem(
                    key: "additionalVideoTrack\(index+1)ID",
                    value: trackID,
                    category: .video,
                    valueType: .number
                ))
                
                // Video dimensions
                let dimensions = try await track.load(.naturalSize)
                items.append(MetadataItem(
                    key: "additionalVideoTrack\(index+1)Resolution",
                    value: "\(Int(dimensions.width)) × \(Int(dimensions.height))",
                    category: .video,
                    valueType: .string
                ))
                
                // Frame rate
                let frameRate = try await track.load(.nominalFrameRate)
                items.append(MetadataItem(
                    key: "additionalVideoTrack\(index+1)FrameRate",
                    value: Float(frameRate),
                    category: .video,
                    valueType: .number
                ))
            }
        }
        
        return items
    }
    
    /// Extract audio track data from video (if available)
    /// - Parameters:
    ///   - asset: The AVAsset to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for audio track data
    private func extractAudioTrackData(_ asset: AVAsset, file: FileReference) async throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Get audio tracks
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        // If no audio tracks, just return empty array (no error)
        if audioTracks.isEmpty {
            return items
        }
        
        // Number of audio tracks
        items.append(MetadataItem(
            key: "audioTrackCount",
            value: audioTracks.count,
            category: .audio,
            valueType: .number
        ))
        
        // Process primary audio track
        let audioTrack = audioTracks[0]
        
        // Track ID
        let trackID = audioTrack.trackID
        items.append(MetadataItem(
            key: "audioTrackID",
            value: trackID,
            category: .audio,
            valueType: .number
        ))
        
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        
        if let formatDescription = formatDescriptions.first {
            // Get format information from CMAudioFormatDescription
            let formatPtr = formatDescription as CMAudioFormatDescription
            
            if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatPtr) {
                // Sample rate
                let sampleRate = streamBasicDescription.pointee.mSampleRate
                items.append(MetadataItem(
                    key: "audioSampleRate",
                    value: sampleRate,
                    category: .audio,
                    valueType: .number
                ))
                
                // Add formatted sample rate
                if sampleRate >= 1000 {
                    items.append(MetadataItem(
                        key: "audioSampleRateFormatted",
                        value: String(format: "%.1f kHz", sampleRate / 1000),
                        category: .audio,
                        valueType: .string
                    ))
                }
                
                // Number of channels
                let channelCount = Int(streamBasicDescription.pointee.mChannelsPerFrame)
                items.append(MetadataItem(
                    key: "audioChannels",
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
                    key: "audioChannelConfiguration",
                    value: channelConfigName,
                    category: .audio,
                    valueType: .string
                ))
                
                // Bits per channel
                let bitsPerChannel = Int(streamBasicDescription.pointee.mBitsPerChannel)
                if bitsPerChannel > 0 {
                    items.append(MetadataItem(
                        key: "audioBitsPerChannel",
                        value: bitsPerChannel,
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
            case "mp4a", "aac ":
                formatName = "AAC"
            case "mp3 ", "mp3":
                formatName = "MP3"
            case "alac":
                formatName = "Apple Lossless (ALAC)"
            case "ac-3", "ac3":
                formatName = "Dolby Digital (AC-3)"
            case "ec-3":
                formatName = "Dolby Digital Plus (E-AC-3)"
            case "flac":
                formatName = "FLAC"
            case "opus":
                formatName = "Opus"
            case "lpcm":
                formatName = "Linear PCM"
            case "raw ":
                formatName = "Raw Audio"
            case "sowt":
                formatName = "PCM (Little Endian)"
            case "twos":
                formatName = "PCM (Big Endian)"
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
                key: "audioFormatID",
                value: formatIDString,
                category: .audio,
                valueType: .string
            ))
        }
        
        // Data rate
        let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
        if estimatedDataRate > 0 {
            items.append(MetadataItem(
                key: "audioBitrate",
                value: estimatedDataRate,
                category: .audio,
                valueType: .number
            ))
            
            // Add formatted bitrate
            if estimatedDataRate >= 1000 {
                items.append(MetadataItem(
                    key: "audioBitrateFormatted",
                    value: String(format: "%.0f kbps", estimatedDataRate / 1000),
                    category: .audio,
                    valueType: .string
                ))
            } else {
                items.append(MetadataItem(
                    key: "audioBitrateFormatted",
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
                key: "audioPreferredVolume",
                value: preferredVolume,
                category: .audio,
                valueType: .number
            ))
        }
        
        // Information for additional audio tracks
        if audioTracks.count > 1 {
            for (index, track) in audioTracks.dropFirst().enumerated() {
                // Track ID
                let trackID = track.trackID
                items.append(MetadataItem(
                    key: "additionalAudioTrack\(index+1)ID",
                    value: trackID,
                    category: .audio,
                    valueType: .number
                ))
                
                // Format
                let formatDescriptions = try await track.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    // Get channel information
                    if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription as CMAudioFormatDescription) {
                        let channelCount = Int(streamBasicDescription.pointee.mChannelsPerFrame)
                        items.append(MetadataItem(
                            key: "additionalAudioTrack\(index+1)Channels",
                            value: channelCount,
                            category: .audio,
                            valueType: .number
                        ))
                        
                        // Sample rate
                        let sampleRate = streamBasicDescription.pointee.mSampleRate
                        items.append(MetadataItem(
                            key: "additionalAudioTrack\(index+1)SampleRate",
                            value: String(format: "%.1f kHz", sampleRate / 1000),
                            category: .audio,
                            valueType: .string
                        ))
                    }
                }
                
                // Language if available
                let languageCode = try await track.load(.languageCode)
                if let code = languageCode, !code.isEmpty {
                    let locale = Locale(identifier: code)
                    let displayName = locale.localizedString(forLanguageCode: code) ?? code
                    
                    items.append(MetadataItem(
                        key: "additionalAudioTrack\(index+1)Language",
                        value: displayName,
                        category: .audio,
                        valueType: .string
                    ))
                }
            }
        }
        
        return items
    }
    
    /// Extract metadata from a video file (tags, content info, etc.)
    /// - Parameters:
    ///   - asset: The AVAsset to extract from
    ///   - file: The file reference for context
    /// - Returns: Array of metadata items for general metadata
    private func extractVideoMetadata(_ asset: AVAsset, file: FileReference) async throws -> [MetadataItem] {
        var items: [MetadataItem] = []
        
        // Common metadata keys mapping
        let commonMetadataMapping: [(String, String, MetadataValueType)] = [
            // Common keys
            (AVMetadataKey.commonKeyTitle.rawValue, "title", .string),
            (AVMetadataKey.commonKeyCreator.rawValue, "creator", .string),
            (AVMetadataKey.commonKeySubject.rawValue, "subject", .string),
            (AVMetadataKey.commonKeyDescription.rawValue, "description", .string),
            (AVMetadataKey.commonKeyPublisher.rawValue, "publisher", .string),
            (AVMetadataKey.commonKeyContributor.rawValue, "contributor", .string),
            (AVMetadataKey.commonKeyCopyrights.rawValue, "copyright", .string),
            (AVMetadataKey.commonKeyCreationDate.rawValue, "creationDate", .date),
            (AVMetadataKey.commonKeyAlbumName.rawValue, "album", .string),
            (AVMetadataKey.commonKeyAuthor.rawValue, "author", .string),
            (AVMetadataKey.commonKeyArtist.rawValue, "artist", .string),
            (AVMetadataKey.commonKeyArtwork.rawValue, "artwork", .image),
            (AVMetadataKey.commonKeyMake.rawValue, "make", .string),
            (AVMetadataKey.commonKeyModel.rawValue, "model", .string),
            (AVMetadataKey.commonKeySoftware.rawValue, "software", .string),
            (AVMetadataKey.quickTimeMetadataKeyDirector.rawValue, "director", .string),
            (AVMetadataKey.quickTimeMetadataKeyProducer.rawValue, "producer", .string),
            (AVMetadataKey.quickTimeMetadataKeyGenre.rawValue, "genre", .string),
            (AVMetadataKey.quickTimeMetadataKeyPerformer.rawValue, "performer", .string),
            (AVMetadataKey.quickTimeMetadataKeyOriginalArtist.rawValue, "originalArtist", .string),
            // Use string literals for keys that don't have constants
            ("com.apple.quicktime.album-artist", "albumArtist", .string),
            (AVMetadataKey.quickTimeMetadataKeyYear.rawValue, "year", .string),
            (AVMetadataKey.quickTimeMetadataKeyEncodedBy.rawValue, "encodedBy", .string),
            (AVMetadataKey.quickTimeMetadataKeyLocationISO6709.rawValue, "location", .string),
            (AVMetadataKey.quickTimeMetadataKeyMake.rawValue, "deviceMake", .string),
            (AVMetadataKey.quickTimeMetadataKeyModel.rawValue, "deviceModel", .string),
            ("com.apple.quicktime.video-encoder", "videoEncoder", .string),
            ("com.apple.iTunes.content-rating", "contentRating", .string),
            ("COMM", "comments", .string)
        ]
        
        // Get all metadata
        let metadata = try await asset.load(.metadata)
        
        // Additional utility to extract chapter information
        let chapterGroups = try await asset.load(.availableChapterLocales)
        if !chapterGroups.isEmpty, let mainLocale = chapterGroups.first {
            let chapters = try await asset.loadChapterMetadataGroups(withTitleLocale: mainLocale, containingItemsWithCommonKeys: [])
            
            if !chapters.isEmpty {
                items.append(MetadataItem(
                    key: "chapterCount",
                    value: chapters.count,
                    category: .video,
                    valueType: .number
                ))
                
                // Extract chapter titles if available
                let chapterTitles = chapters.compactMap { group -> String? in
                    let items = group.items.filter { $0.commonKey == AVMetadataKey.commonKeyTitle }
                    return items.first?.stringValue
                }
                
                if !chapterTitles.isEmpty {
                    items.append(MetadataItem(
                        key: "chapterTitles",
                        value: chapterTitles,
                        category: .video,
                        valueType: .array
                    ))
                }
            }
        }
        
        // Process all metadata items
        for metadataItem in metadata {
            // Get key and value
            let identifier = metadataItem.identifier
            let commonKey = metadataItem.commonKey
            
            // Get key string - try common key first, then identifier, fallback to unknown
            let keyString = commonKey?.rawValue as? String ?? 
                            identifier?.rawValue as? String ?? "<unknown key>"
            
            // Skip artwork for now (it's binary data)
            if commonKey == AVMetadataKey.commonKeyArtwork {
                items.append(MetadataItem(
                    key: "hasArtwork",
                    value: true,
                    category: .video,
                    valueType: .boolean
                ))
                continue
            }
            
            // Get key space
            let keySpace = metadataItem.keySpace
            
            // Skip iTunes-specific keys starting with "com.apple.iTunes"
            if let keySpaceString = keySpace?.rawValue as? String,
               keySpaceString == "itsk" && keyString.starts(with: "com.apple.iTunes") {
                continue
            }
            
            // Convert metadata value to appropriate Swift type
            guard let value = metadataItem.value else {
                continue
            }
            
            // Find mapping for this key
            var displayKey = keyString
            var valueType: MetadataValueType = .string
            var category: MetadataCategory = .video
            
            for (metadataKey, mappedKey, mappedType) in commonMetadataMapping {
                if keyString == metadataKey {
                    displayKey = mappedKey
                    valueType = mappedType
                    
                    // If this is an audio-related key, use audio category
                    if mappedKey.contains("artist") || 
                       mappedKey.contains("album") || 
                       mappedKey.contains("audio") ||
                       mappedKey.contains("encoded") {
                        category = .audio
                    }
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
                        category: category,
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
                            category: category,
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
                category: category,
                valueType: valueType
            ))
        }
        
        return items
    }
    
    // MARK: - Helper Methods
    
    /// Get the rotation angle from a transform matrix
    /// - Parameter transform: The transform matrix
    /// - Returns: The rotation angle in degrees (0, 90, 180, 270)
    private func getRotationFromTransform(_ transform: CGAffineTransform) -> Int {
        var rotation = 0
        
        if transform.a == 0 && transform.b == 1 && transform.c == -1 && transform.d == 0 {
            rotation = 90
        } else if transform.a == -1 && transform.b == 0 && transform.c == 0 && transform.d == -1 {
            rotation = 180
        } else if transform.a == 0 && transform.b == -1 && transform.c == 1 && transform.d == 0 {
            rotation = 270
        }
        
        return rotation
    }
    
    /// Get the standard resolution name for common resolutions
    /// - Parameters:
    ///   - width: The video width in pixels
    ///   - height: The video height in pixels
    /// - Returns: The resolution name, or empty string if not a standard resolution
    private func getResolutionName(width: Int, height: Int) -> String {
        // Check for common video resolutions and return standard names
        let maxDimension = max(width, height)
        let minDimension = min(width, height)
        
        // Standard resolutions (UHD, HD, etc.)
        if maxDimension >= 7680 && minDimension >= 4320 {
            return "8K UHD (7680×4320)"
        } else if maxDimension >= 3840 && minDimension >= 2160 {
            return "4K UHD (3840×2160)"
        } else if maxDimension >= 2560 && minDimension >= 1440 {
            return "2.5K QHD (2560×1440)"
        } else if maxDimension >= 1920 && minDimension >= 1080 {
            return "Full HD (1920×1080)"
        } else if maxDimension >= 1280 && minDimension >= 720 {
            return "HD (1280×720)"
        } else if (width == 720 && height == 576) || (width == 576 && height == 720) {
            return "SD PAL (720×576)"
        } else if (width == 720 && height == 480) || (width == 480 && height == 720) {
            return "SD NTSC (720×480)"
        } else if maxDimension >= 640 && minDimension >= 480 {
            return "VGA (640×480)"
        } else if maxDimension >= 320 && minDimension >= 240 {
            return "QVGA (320×240)"
        }
        
        return ""
    }
    
    /// Helper method to convert a 4-char code to a string
    /// - Parameter fourCharCode: The 4-char code as a UInt32
    /// - Returns: A string representation of the 4-char code
    private func fourCharCodeToString(_ fourCharCode: UInt32) -> String {
        let chars: [CChar] = [
            CChar((fourCharCode >> 24) & 0xFF),
            CChar((fourCharCode >> 16) & 0xFF),
            CChar((fourCharCode >> 8) & 0xFF),
            CChar(fourCharCode & 0xFF),
            0
        ]
        
        return withUnsafePointer(to: chars) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 5) { charPtr in
                String(cString: charPtr)
            }
        }
    }
}
