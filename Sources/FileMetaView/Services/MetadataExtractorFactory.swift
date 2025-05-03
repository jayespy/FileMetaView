import Foundation
import UniformTypeIdentifiers
import os.log

/// Factory class responsible for creating and returning appropriate metadata extractors based on file type
class MetadataExtractorFactory {
    /// Logger for this factory
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "MetadataExtractorFactory")
    
    /// All available extractors
    private var extractors: [MetadataExtractor]
    
    /// Initialize the factory with all available extractors
    init() {
        // Create instances of all available extractors
        // The order is important as it determines the fallback order
        extractors = [
            BasicMetadataExtractor(), // Always include basic extractor
            ImageMetadataExtractor(),
            AudioMetadataExtractor(),
            VideoMetadataExtractor(),
            DocumentMetadataExtractor()
        ]
        
        logger.info("MetadataExtractorFactory initialized with \(self.extractors.count) extractors")
    }
    
    /// Get the appropriate extractor for a file
    /// - Parameter file: The file reference to determine the extractor for
    /// - Returns: The most appropriate MetadataExtractor for the file type
    func getExtractor(for file: FileReference) -> MetadataExtractor {
        logger.info("Selecting extractor for file: \(file.url.lastPathComponent) (type: \(file.type))")
        
        // Always include the BasicMetadataExtractor in the results
        var matchingExtractors: [(extractor: MetadataExtractor, score: Int)] = []
        
        // Find all extractors that can handle this file type
        for extractor in extractors {
            if extractor.canHandle(fileType: file.type, fileExtension: file.fileExtension) {
                // Calculate score based on priority and whether it's specialized
                let score = extractor.priority()
                matchingExtractors.append((extractor, score))
                
                self.logger.debug("Matched extractor: \(extractor.extractorName()) with priority \(score)")
            }
        }
        
        // Sort by score (descending)
        matchingExtractors.sort { $0.score > $1.score }
        
        // If no matching extractors, fallback to BasicMetadataExtractor
        if matchingExtractors.isEmpty {
            self.logger.info("No specialized extractor found, using BasicMetadataExtractor")
            return self.extractors.first { $0 is BasicMetadataExtractor } ?? BasicMetadataExtractor()
        }
        
        // Return the highest scoring extractor
        self.logger.info("Selected extractor: \(matchingExtractors[0].extractor.extractorName())")
        return matchingExtractors[0].extractor
    }
    
    /// Get multiple extractors for a file (for comprehensive metadata extraction)
    /// - Parameters:
    ///   - file: The file reference to determine extractors for
    ///   - limit: Optional maximum number of extractors to return
    ///   - optimizeForPerformance: Whether to consider performance when selecting extractors
    /// - Returns: Array of appropriate extractors in priority order
    func getExtractors(for file: FileReference, limit: Int? = nil, optimizeForPerformance: Bool = true) -> [MetadataExtractor] {
        self.logger.info("Selecting multiple extractors for file: \(file.url.lastPathComponent) (size: \(file.formattedSize))")
        
        // Find all extractors that can handle this file type
        var matchingExtractors: [(extractor: MetadataExtractor, score: Int)] = []
        
        let fileSize = file.size
        
        for extractor in extractors {
            if extractor.canHandle(fileType: file.type, fileExtension: file.fileExtension) {
                // Check file size limit if optimizing for performance
                if optimizeForPerformance, let sizeLimit = extractor.recommendedFileSizeLimit(), fileSize > sizeLimit {
                    logger.info("Skipping \(extractor.extractorName()) due to file size limit (\(sizeLimit) bytes)")
                    continue
                }
                
                // Calculate score based on multiple factors
                var score = extractor.priority()
                
                // Adjust score based on performance impact if relevant
                if optimizeForPerformance && fileSize > 50 * 1024 * 1024 { // > 50MB
                    // Reduce score for high-impact extractors on large files
                    let impactPenalty = extractor.performanceImpact() * 5
                    score -= impactPenalty
                    
                    // For basic extractor, always keep score at least at 1
                    if extractor is BasicMetadataExtractor && score < 1 {
                        score = 1
                    }
                }
                
                // Only include extractors with positive scores
                if score > 0 {
                    matchingExtractors.append((extractor, score))
                    self.logger.debug("Matched extractor: \(extractor.extractorName()) with adjusted score \(score)")
                }
            }
        }
        
        // Sort by score (descending)
        matchingExtractors.sort { $0.score > $1.score }
        
        // Apply limit if specified
        if let limit = limit, limit < matchingExtractors.count {
            matchingExtractors = Array(matchingExtractors.prefix(limit))
        }
        
        // Extract just the extractors from the tuples
        let result = matchingExtractors.map { $0.extractor }
        
        // If no matching extractors, fallback to BasicMetadataExtractor
        if result.isEmpty {
            self.logger.info("No extractors found or all excluded due to performance constraints, using BasicMetadataExtractor")
            return [BasicMetadataExtractor()]
        }
        
        // Log the final selection
        let extractorNames = result.map { $0.extractorName() }.joined(separator: ", ")
        self.logger.info("Selected \(result.count) extractors: \(extractorNames)")
        
        return result
    }
    
    /// Determine the appropriate extractor type for a UTI file type
    /// - Parameter fileType: The UTI string to check
    /// - Returns: The general category of extractor that should handle this file type
    func determineExtractorType(for fileType: String) -> String {
        // Check for image types
        if UTType(fileType)?.conforms(to: UTType.image) == true {
            return "Image"
        }
        
        // Check for audio types
        if UTType(fileType)?.conforms(to: UTType.audio) == true {
            return "Audio"
        }
        
        // Check for video types
        if UTType(fileType)?.conforms(to: UTType.movie) == true || 
           UTType(fileType)?.conforms(to: UTType.video) == true {
            return "Video"
        }
        
        // Check for document types
        if UTType(fileType)?.conforms(to: UTType.text) == true ||
           UTType(fileType)?.conforms(to: UTType.pdf) == true {
            return "Document"
        }
        
        // Default to basic
        return "Basic"
    }
    
    /// Extract all metadata from a file using the appropriate extractors
    /// - Parameters:
    ///   - file: The file reference to extract metadata from
    ///   - combinedResults: Whether to combine results from multiple extractors
    ///   - optimizeForPerformance: Whether to consider performance when selecting extractors
    /// - Returns: MetadataExtractionResult with the extracted items
    /// - Throws: FileAccessError if extraction fails
    func extractMetadata(from file: FileReference, combinedResults: Bool = true, optimizeForPerformance: Bool = true) async throws -> MetadataExtractionResult {
        self.logger.info("Extracting metadata for file: \(file.url.lastPathComponent) (size: \(file.formattedSize))")
        
        // Mark the start time for performance metrics
        let startTime = Date()
        
        // Determine the appropriate limit for extractors based on file size
        let extractorLimit: Int?
        if optimizeForPerformance {
            if file.size > 1024 * 1024 * 1024 { // > 1GB
                extractorLimit = 1 // Only use one extractor for extremely large files
            } else if file.size > 500 * 1024 * 1024 { // > 500MB
                extractorLimit = 2 // Use at most two extractors for very large files
            } else if file.size > 100 * 1024 * 1024 { // > 100MB
                extractorLimit = 3 // Use at most three extractors for large files
            } else {
                extractorLimit = nil // No limit for normal-sized files
            }
        } else {
            extractorLimit = nil
        }
        
        // Get appropriate extractors
        let selectedExtractors = getExtractors(for: file, limit: extractorLimit, optimizeForPerformance: optimizeForPerformance)
        
        // If no extractors available, throw error
        guard !selectedExtractors.isEmpty else {
            throw FileAccessError.unsupportedFileType(file.url, "No suitable metadata extractor found")
        }
        
        // If only using one extractor (or not combining results)
        if selectedExtractors.count == 1 || !combinedResults {
            let primaryExtractor = selectedExtractors[0]
            let extractorStartTime = Date()
            
            do {
                // Use a task with priority for extraction
                let items = try await Task.detached(priority: .userInitiated) {
                    try await primaryExtractor.extractMetadata(from: file)
                }.value
                
                // Create metrics for the extraction
                let metrics = ExtractionMetrics(
                    startTime: extractorStartTime,
                    endTime: Date(),
                    itemCount: items.count,
                    fileSize: file.size,
                    memoryIntensive: primaryExtractor.performanceImpact() >= 8
                )
                
                return MetadataExtractionResult(
                    items: items,
                    extractor: primaryExtractor,
                    metrics: metrics
                )
            } catch {
                // If this is a file size limitation, convert to appropriate error
                if let sizeLimit = primaryExtractor.recommendedFileSizeLimit(), 
                   file.size > sizeLimit, 
                   !(error is FileAccessError) {
                    throw FileAccessError.fileTooLarge(file.url, file.size)
                }
                throw error
            }
        }
        
        // Extract metadata from all extractors and combine
        var allItems: [MetadataItem] = []
        var warnings: [String] = []
        var usedExtractors: [MetadataExtractor] = []
        var allMetrics: [ExtractionMetrics] = []
        
        // Extract in parallel if file is not too large
        if file.size < 50 * 1024 * 1024 && selectedExtractors.count > 1 {
            // Create a task group for parallel extraction
            try await withThrowingTaskGroup(of: (MetadataExtractor, [MetadataItem], ExtractionMetrics?).self) { group in
                // Add extraction tasks
                for extractor in selectedExtractors {
                    group.addTask {
                        let extractorStartTime = Date()
                        do {
                            let items = try await extractor.extractMetadata(from: file)
                            let metrics = ExtractionMetrics.create(
                                from: extractorStartTime,
                                items: items, 
                                fileSize: file.size,
                                memoryIntensive: extractor.performanceImpact() >= 8
                            )
                            return (extractor, items, metrics)
                        } catch {
                            // Return empty array for failed extractor
                            return (extractor, [], nil)
                        }
                    }
                }
                
                // Process results as they complete
                for try await (extractor, items, metrics) in group {
                    if !items.isEmpty {
                        allItems.append(contentsOf: items)
                        usedExtractors.append(extractor)
                        if let metrics = metrics {
                            allMetrics.append(metrics)
                        }
                    } else {
                        // Log warning for failed extractor
                        let warningMessage = "Failed to extract metadata with \(extractor.extractorName())"
                        warnings.append(warningMessage)
                        self.logger.warning("\(warningMessage)")
                    }
                }
            }
        } else {
            // Sequential extraction for large files
            for extractor in selectedExtractors {
                let extractorStartTime = Date()
                do {
                    let items = try await extractor.extractMetadata(from: file)
                    allItems.append(contentsOf: items)
                    usedExtractors.append(extractor)
                    
                    // Create metrics
                    let metrics = ExtractionMetrics.create(
                        from: extractorStartTime,
                        items: items, 
                        fileSize: file.size,
                        memoryIntensive: extractor.performanceImpact() >= 8
                    )
                    allMetrics.append(metrics)
                    
                    // Log performance information
                    self.logger.info("\(extractor.extractorName()) extracted \(items.count) items in \(metrics.duration) seconds")
                } catch {
                    // Log error but continue with other extractors
                    let warningMessage = "Failed to extract metadata with \(extractor.extractorName()): \(error.localizedDescription)"
                    warnings.append(warningMessage)
                    self.logger.warning("\(warningMessage)")
                }
            }
        }
        
        // If no successful extractions, throw an error
        if allItems.isEmpty {
            throw FileAccessError.metadataExtractionFailed(file.url, NSError(
                domain: "com.example.FileMetaView.metadata",
                code: 1005,
                userInfo: [NSLocalizedDescriptionKey: "All metadata extractors failed"]
            ))
        }
        
        // Calculate overall metrics
        let overallMetrics = ExtractionMetrics(
            startTime: startTime,
            endTime: Date(),
            itemCount: allItems.count,
            fileSize: file.size,
            memoryIntensive: allMetrics.contains { $0.memoryIntensive }
        )
        
        // Create a combined result with the primary extractor
        return MetadataExtractionResult(
            items: removeDuplicateMetadataItems(allItems),
            extractor: usedExtractors.first!,
            warnings: warnings,
            metrics: overallMetrics
        )
    }
    
    /// Remove duplicate metadata items from a combined list
    /// - Parameter items: The metadata items to deduplicate
    /// - Returns: Deduplicated list of metadata items
    private func removeDuplicateMetadataItems(_ items: [MetadataItem]) -> [MetadataItem] {
        var uniqueItems: [MetadataItem] = []
        var seenKeys = Set<String>()
        
        // Process items by category priority (basic items first)
        let sortedItems = items.sorted { (item1, item2) -> Bool in
            if item1.category.sortOrder != item2.category.sortOrder {
                return item1.category.sortOrder < item2.category.sortOrder
            }
            return item1.key < item2.key
        }
        
        for item in sortedItems {
            // Create a unique identifier for the item based on key and value type
            let uniqueKey = "\(item.category.rawValue)_\(item.key)_\(item.valueType.rawValue)"
            
            // Skip if we've already seen this key
            if !seenKeys.contains(uniqueKey) {
                uniqueItems.append(item)
                seenKeys.insert(uniqueKey)
            }
        }
        
        return uniqueItems
    }
    
    /// Register a custom extractor with the factory
    /// - Parameter extractor: The MetadataExtractor to register
    func registerExtractor(_ extractor: MetadataExtractor) {
        self.extractors.append(extractor)
        self.logger.info("Registered new extractor: \(extractor.extractorName())")
    }
    
    /// Unregister an extractor type from the factory
    /// - Parameter extractorName: The name of the extractor to remove
    func unregisterExtractor(named extractorName: String) {
        let initialCount = self.extractors.count
        self.extractors.removeAll { $0.extractorName() == extractorName }
        
        let removedCount = initialCount - self.extractors.count
        if removedCount > 0 {
            self.logger.info("Unregistered \(removedCount) extractor(s) named: \(extractorName)")
        }
    }
}
