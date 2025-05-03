import Foundation
import SwiftUI
import Combine
import os.log

/// Main view model for the application, handling state management and business logic
class AppViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The currently selected file
    @Published var selectedFile: FileReference?
    
    /// The metadata items extracted from the selected file
    @Published var metadata: [MetadataItem] = []
    
    /// Whether metadata is currently being loaded
    @Published var isLoading: Bool = false
    
    /// Any error that occurred during file selection or metadata extraction
    @Published var error: FileAccessError?
    
    /// Search text for filtering metadata items
    @Published var searchText: String = ""
    
    /// Whether the error alert is currently showing
    @Published var showingError: Bool = false
    
    /// Whether the permission request is being shown
    @Published var showingPermissionRequest: Bool = false
    
    /// URL for permission request
    @Published var permissionRequestURL: URL? = nil
    
    /// Whether the unsupported file type dialog is being shown
    @Published var showingUnsupportedFileType: Bool = false
    
    /// URL of the unsupported file
    @Published var unsupportedFileURL: URL? = nil
    
    /// Whether the file drop target is active
    @Published var isDropTargetActive: Bool = false
    
    /// Whether to attempt extraction on unsupported file types
    @Published var allowUnsupportedFileTypes: Bool = false
    
    /// Selected metadata categories for filtering
    @Published var selectedCategories: Set<MetadataCategory> = []
    
    /// Progress of metadata loading (0.0 to 1.0)
    @Published var loadingProgress: Double = 0.0
    
    /// Flag to indicate if a large file is being processed
    @Published var isLargeFile: Bool = false
    
    // MARK: - Dependencies
    
    /// Service for handling file selection
    let fileSelectionService: FileSelectionService
    
    /// Factory for creating metadata extractors
    let extractorFactory: MetadataExtractorFactory
    
    /// User preferences
    var userPreferences: UserPreferences?
    
    /// Logger for the view model
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "AppViewModel")
    
    // MARK: - Internal State
    
    /// Private stored metadata before filtering
    private var allMetadata: [MetadataItem] = []
    
    /// Set to store subscription cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Task reference for metadata loading
    private var metadataLoadingTask: Task<Void, Never>?
    
    /// Task identifier to track the most recent loading task
    private var currentTaskID: UUID?
    
    /// The number of metadata items loaded so far during progressive loading
    private var loadedItemCount: Int = 0
    
    /// Whether to show the copy confirmation popup
    @Published var showingCopyConfirmation: Bool = false
    
    /// Copy confirmation message
    @Published var copyConfirmationMessage: String = "Copied to clipboard"
    
    /// File size threshold for large file handling (100MB)
    private let largeFileThreshold: Int64 = 100 * 1024 * 1024
    
    /// Extreme file size threshold (1GB) - for very limited extraction
    private let extremeFileThreshold: Int64 = 1024 * 1024 * 1024
    
    /// Chunk size for progressive loading (number of metadata items per chunk)
    private let progressiveLoadingChunkSize: Int = 10
    
    /// Timeout for metadata extraction (seconds)
    private let metadataExtractionTimeout: TimeInterval = 60
    
    /// Maximum time to spend on a single extractor for large files (seconds)
    private let extractorTimeLimit: TimeInterval = 15
    
    // MARK: - Initialization
    
    /// Initialize the view model with dependencies
    /// - Parameters:
    ///   - fileSelectionService: Service for handling file selection
    ///   - extractorFactory: Factory for creating metadata extractors
    ///   - userPreferences: Optional user preferences to observe
    init(
        fileSelectionService: FileSelectionService = FileSystemSelectionService(),
        extractorFactory: MetadataExtractorFactory = MetadataExtractorFactory(),
        userPreferences: UserPreferences? = nil
    ) {
        self.fileSelectionService = fileSelectionService
        self.extractorFactory = extractorFactory
        self.userPreferences = userPreferences
        
        // Initialize selected categories from user preferences or with all categories as default
        if let preferences = userPreferences {
            self.selectedCategories = preferences.defaultCategories
        } else {
            self.selectedCategories = Set(MetadataCategory.allCases)
        }
        
        // Direct search text handling without debounce to ensure immediate response
        $searchText
            .sink { [weak self] newValue in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.filterMetadata()
                    
                    // Print for debugging
                    print("Search text updated: \"\(newValue)\"")
                }
            }
            .store(in: &cancellables)
        
        // Set up category filtering
        $selectedCategories
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.filterMetadata()
                }
            }
            .store(in: &cancellables)
        
        // Observe user preferences changes
        setupPreferencesObservation()
        
        logger.info("AppViewModel initialized")
    }
    
    /// Set up observation of user preferences changes
    private func setupPreferencesObservation() {
        guard let preferences = userPreferences else { return }
        
        preferences.$defaultCategories
            .sink { [weak self] newCategories in
                // When preferences change and no file is selected, 
                // update selected categories to match preferences
                if self?.selectedFile == nil {
                    self?.selectedCategories = newCategories
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Select a file using the file selection service
    /// - Returns: True if selection was successful, false otherwise
    @MainActor
    func selectFile() async -> Bool {
        // Reset state
        isLoading = true
        error = nil
        
        do {
            logger.info("Initiating file selection")
            let file = try await fileSelectionService.selectFile()
            
            // Update the selected file
            selectedFile = file
            logger.info("File selected: \(file.name)")
            
            // Load metadata for the selected file
            await loadMetadata()
            isLoading = false
            return true
        } catch let selectionError as FileAccessError {
            // Only show error if it's not a user cancellation
            if case .operationCancelled = selectionError {
                logger.info("File selection cancelled by user")
            } else {
                handleError(selectionError)
            }
            isLoading = false
            return false
        } catch {
            // Handle any other errors
            handleError(FileAccessError.from(error: error))
            isLoading = false
            return false
        }
    }
    
    /// Handle a file drop operation
    /// - Parameter url: The URL of the dropped file
    /// - Returns: True if the drop was handled successfully, false otherwise
    @MainActor
    func handleFileDrop(url: URL) async -> Bool {
        // Reset state
        isLoading = true
        error = nil
        
        do {
            logger.info("Handling dropped file: \(url.lastPathComponent)")
            let file = try fileSelectionService.handleFileDropped(url: url)
            
            // Update the selected file
            selectedFile = file
            logger.info("Dropped file accepted: \(file.name)")
            
            // Load metadata for the selected file
            await loadMetadata()
            isLoading = false
            return true
        } catch {
            // Handle any errors
            handleError(error as? FileAccessError ?? FileAccessError.from(error: error))
            isLoading = false
            return false
        }
    }
    
    /// Load metadata for the currently selected file
    @MainActor
    func loadMetadata() async {
        guard let file = selectedFile else {
            logger.warning("Cannot load metadata: No file selected")
            return
        }
        
        // Generate a unique ID for this task
        let taskID = UUID()
        currentTaskID = taskID
        
        // Cancel any previous loading task but don't show error
        if let task = metadataLoadingTask {
            task.cancel()
            logger.info("Cancelled previous metadata loading task during file switch")
            metadataLoadingTask = nil
        }
        
        // Reset state
        isLoading = true
        error = nil
        allMetadata = []
        metadata = []
        loadedItemCount = 0
        loadingProgress = 0.0
        
        // Reset selected categories to defaults when loading a new file
        if let preferences = userPreferences {
            // Use the user's default categories
            selectedCategories = preferences.defaultCategories
            logger.info("Set selected categories from user preferences: \(self.selectedCategories.count) categories")
        } else {
            // Default to all categories if no preferences are available
            selectedCategories = Set(MetadataCategory.allCases)
            logger.info("No preferences found, using all categories")
        }
        
        // Check if this is a large file that needs special handling
        isLargeFile = file.size > largeFileThreshold
        if isLargeFile {
            let sizeInfo = file.size > extremeFileThreshold ? 
                "extremely large (\(file.formattedSize))" : "large (\(file.formattedSize))"
            logger.info("Large file detected (\(sizeInfo)). Using optimized loading.")
        }
        
        // Create a new task for metadata loading
        metadataLoadingTask = Task {
            do {
                logger.info("Loading metadata for file: \(file.name)")
                
                // Set up a cancellation button in the UI after a short delay for long-running operations
                let cancellationSetupTask = Task { @MainActor in
                    // Wait a short period before showing cancellation UI elements
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Only show cancellation UI if still loading and this is still the current task
                    if isLoading && !Task.isCancelled && self.currentTaskID == taskID {
                        // This is where we would update UI to show a cancel button
                        // The actual UI update would be implemented elsewhere
                        logger.info("Long-running operation detected, cancellation UI shown")
                    }
                }
                
                // Execute appropriate loading strategy
                if isLargeFile {
                    // Use progressive loading for large files
                    await loadMetadataProgressively(for: file)
                } else {
                    // Standard loading for normal files
                    let result = try await extractorFactory.extractMetadata(from: file)
                    
                    try checkCancellation()
                    
                    // Check if this is still the current task before updating UI
                    if !Task.isCancelled && self.currentTaskID == taskID {
                        await MainActor.run {
                            updateMetadataState(with: result.items, warnings: result.warnings)
                            loadingProgress = 1.0
                        }
                    }
                }
                
                // Cancel the cancellation setup task since we're done
                cancellationSetupTask.cancel()
            } catch let error as FileAccessError {
                if case .fileTooLarge = error {
                    // Already a proper file too large error
                    // Only handle error if this is still the current task
                    if !Task.isCancelled && self.currentTaskID == taskID {
                        await MainActor.run {
                            handleError(error)
                        }
                    }
                } else if case .timeout = error {
                    // Already a timeout error
                    if !Task.isCancelled && self.currentTaskID == taskID {
                        await MainActor.run {
                            handleError(error)
                        }
                    }
                } else if isLargeFile && file.size > extremeFileThreshold {
                    // For extremely large files that failed with other errors, convert to too large error
                    if !Task.isCancelled && self.currentTaskID == taskID {
                        await MainActor.run {
                            handleError(FileAccessError.fileTooLarge(file.url, file.size))
                        }
                    }
                } else if isLargeFile && file.size > (largeFileThreshold * 10) {
                    // For very large files that failed, might be timeout related
                    if !Task.isCancelled && self.currentTaskID == taskID {
                        await MainActor.run {
                            handleError(FileAccessError.timeout(file.url, "Metadata extraction took too long for this large file"))
                        }
                    }
                } else {
                    // Handle other errors
                    if !Task.isCancelled && self.currentTaskID == taskID {
                        await MainActor.run {
                            handleError(error)
                        }
                    }
                }
            } catch {
                // Handle any other errors
                // Only handle error if this is still the current task
                if !Task.isCancelled && self.currentTaskID == taskID {
                    await MainActor.run {
                        handleError(FileAccessError.from(error: error, url: file.url))
                    }
                }
            }
            
            // Always reset loading state when complete
            // Only update loading state if this is still the current task
            if !Task.isCancelled && self.currentTaskID == taskID {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    /// Load metadata progressively in chunks for large files
    @MainActor
    private func loadMetadataProgressively(for file: FileReference) async {
        do {
            // Get appropriate extractors
            var extractors = extractorFactory.getExtractors(for: file)
            
            guard !extractors.isEmpty else {
                throw FileAccessError.unsupportedFileType(file.url, "No suitable metadata extractor found")
            }
            
            // For extremely large files, reduce the number of extractors to only essential ones
            if file.size > extremeFileThreshold {
                logger.info("Extremely large file detected. Limiting to essential extractors only.")
                // Keep only the highest priority extractors
                extractors = extractors.sorted { $0.priority() > $1.priority() }
                if extractors.count > 2 {
                    extractors = Array(extractors.prefix(2))
                }
            }
            
            // Process each extractor in background with a global timeout
            let startTime = Date()
            let timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(self.metadataExtractionTimeout * 1_000_000_000))
                    
                    if !Task.isCancelled && isLoading {
                        logger.warning("Metadata extraction timed out after \(self.metadataExtractionTimeout) seconds")
                        metadataLoadingTask?.cancel()
                        await MainActor.run {
                            handleError(FileAccessError.timeout(file.url, "Metadata extraction timed out after \(Int(self.metadataExtractionTimeout)) seconds"))
                            isLoading = false
                        }
                    }
                } catch {
                    // Task was likely cancelled, no need to do anything
                    logger.info("Timeout task was cancelled")
                }
            }
            
            // Make sure we properly clean up the timeout task when done
            defer {
                timeoutTask.cancel()
                logger.info("Cancelled timeout monitoring task")
            }
            
            // Check for cancellation before processing extractors
            if Task.isCancelled {
                throw FileAccessError.operationCancelled("Metadata loading cancelled")
            }
            
            // Process each extractor in background
            for (index, extractor) in extractors.enumerated() {
                // Check for cancellation between extractors
                try checkCancellation(message: "Metadata loading cancelled during progressive loading")
                
                // Skip remaining extractors if we've been processing for too long
                if Date().timeIntervalSince(startTime) > self.metadataExtractionTimeout * 0.8 {
                    logger.warning("Approaching timeout limit, skipping remaining extractors")
                    break
                }
                
                // Calculate progress base for this extractor
                let progressBase = Double(index) / Double(extractors.count)
                let progressIncrement = 1.0 / Double(extractors.count)
                
                // Set a time limit for each extractor based on file size
                let timeLimit = file.size > extremeFileThreshold ? 
                    extractorTimeLimit * 0.5 : // Half time for extremely large files
                    extractorTimeLimit         // Normal time for large files
                
                try await processExtractorProgressively(extractor, for: file, progressBase: progressBase, 
                                                      progressIncrement: progressIncrement, timeLimit: timeLimit)
            }
            
            // Proceed with extraction if not cancelled
            logger.info("Completed progressive loading of metadata")
            loadingProgress = 1.0
        } catch let error as MetadataExtractionError {
            if case .operationCancelled = error {
                logger.info("Metadata extraction was cancelled")
                await MainActor.run {
                    self.error = FileAccessError.operationCancelled("Operation was cancelled")
                    isLoading = false
                }
            } else {
                // Convert and handle other extraction errors
                handleError(FileAccessError.from(error: error, url: file.url))
            }
        } catch {
            // Handle any other errors
            handleError(error as? FileAccessError ?? FileAccessError.from(error: error, url: file.url))
        }
    }
    
    /// Process a single extractor progressively for large files
    @MainActor
    private func processExtractorProgressively(_ extractor: MetadataExtractor, for file: FileReference, 
                                             progressBase: Double, progressIncrement: Double, 
                                             timeLimit: TimeInterval = 15) async throws {
        // Record start time for this extractor
        let extractorStartTime = Date()
        
        // Create a background task for this extractor with timeout
        let extractorTimeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeLimit * 1_000_000_000))
            if !Task.isCancelled && isLoading {
                logger.warning("Extractor \(extractor.extractorName()) timed out after \(timeLimit) seconds")
                // We don't throw an error here, just log and move on to the next extractor
            }
            return nil as [MetadataItem]?
        }
        
        // Create a task group for extractor processing with timeout
        try await withThrowingTaskGroup(of: [MetadataItem]?.self) { group in
            // Add the extraction task
            group.addTask {
                do {
                    // Use a background queue for CPU-intensive extraction
                    let extractionTask = Task.detached(priority: .userInitiated) {
                        try await extractor.extractMetadata(from: file)
                    }
                    
                    // Wait for either completion or timeout
                    return try await extractionTask.value
                } catch {
                    self.logger.error("Error in extractor \(extractor.extractorName()): \(error.localizedDescription)")
                    return nil
                }
            }
            
            // Add the timeout task to the group
            group.addTask {
                do {
                    return try await extractorTimeoutTask.value
                } catch {
                    self.logger.warning("Timeout task failed: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // Process the first result (either extraction result or timeout)
            var hasProcessedResult = false
            
            do {
                for try await result in group {
                    // If we already processed a result, skip
                    if hasProcessedResult { continue }
                    hasProcessedResult = true
                
                // Cancel both tasks when one completes
                group.cancelAll()
                
                // If we got a nil result, it was a timeout or error
                guard let items = result else {
                    logger.warning("No results from extractor \(extractor.extractorName())")
                    return
                }
                
                    // Calculate time spent
                    let processingTime = Date().timeIntervalSince(extractorStartTime)
                    logger.info("Extractor \(extractor.extractorName()) completed in \(String(format: "%.2f", processingTime)) seconds")
                
                // Limit the number of items for extremely large files
                let processedItems: [MetadataItem]
                if file.size > extremeFileThreshold && items.count > 15 {
                    processedItems = Array(items.prefix(15))
                    logger.info("Limited metadata items to 15 for extremely large file")
                } else {
                    processedItems = items
                }
                
                    // Process items in chunks
                    let warnings: [String] = []
                    var itemsProcessed = 0
                    let totalItems = processedItems.count
                    
                    for (chunkIndex, chunk) in processedItems.chunked(into: progressiveLoadingChunkSize).enumerated() {
                    // Check for cancellation between chunks
                    try checkCancellation(message: "Metadata loading cancelled during chunk processing")
                    
                    // Update UI with this chunk
                    updateMetadataState(with: chunk, warnings: warnings, append: true)
                    
                    itemsProcessed += chunk.count
                    
                        // Update progress
                        let chunkProgress = Double(chunkIndex + 1) / Double(max(1, (totalItems / progressiveLoadingChunkSize)))
                        loadingProgress = progressBase + (progressIncrement * chunkProgress)
                        
                        // Small delay to allow UI to update and remain responsive
                        // Adjust delay based on file size - longer for extremely large files
                        let delayTime = file.size > extremeFileThreshold ? 20_000_000 : 10_000_000 // 20ms or 10ms
                        try? await Task.sleep(nanoseconds: UInt64(delayTime))
                    }
                    
                    logger.info("Processed \(itemsProcessed) items progressively from \(extractor.extractorName())")
                }
            } catch {
                logger.error("Error in task group: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// Update the metadata state with new items
    @MainActor
    private func updateMetadataState(with items: [MetadataItem], warnings: [String] = [], append: Bool = false) {
        if append {
            // Add new items to existing collection
            allMetadata.append(contentsOf: items)
            loadedItemCount += items.count
        } else {
            // Replace existing items
            allMetadata = items
            loadedItemCount = items.count
        }
        
        logger.info("Loaded \(self.loadedItemCount) total metadata items")
        
        // Log any warnings
        for warning in warnings {
            logger.warning("\(warning)")
        }
        
        // Filter the metadata based on current filters
        filterMetadata()
    }
    
    /// Cancel the current metadata loading operation - explicitly called by the user
    func cancelMetadataLoading() {
        if let task = metadataLoadingTask {
            task.cancel()
            logger.info("User explicitly cancelled metadata loading task")
            
            // Reset task tracking
            currentTaskID = nil
            metadataLoadingTask = nil
            
            Task { @MainActor in
                // Reset loading state
                isLoading = false
                loadingProgress = 0.0
                self.error = FileAccessError.operationCancelled("Operation was cancelled by user")
            }
        }
    }
    
    /// Check if a cancellation was requested during a long operation
    /// - Parameter message: Optional message providing context for the cancellation
    /// - Throws: FileAccessError.operationCancelled if the task was cancelled
    func checkCancellation(message: String = "Operation cancelled") throws {
        guard !Task.isCancelled else {
            logger.info("Task cancellation detected: \(message)")
            throw FileAccessError.operationCancelled(message)
        }
    }
    
    /// Refresh metadata for the current file
    @MainActor
    func refreshMetadata() async {
        guard let file = selectedFile else { return }
        
        // Cancel any ongoing metadata extraction without showing an error
        if let task = metadataLoadingTask {
            task.cancel()
            logger.info("Cancelled metadata loading task during refresh")
            metadataLoadingTask = nil
        }
        
        // Create a new file reference to ensure we get fresh metadata
        selectedFile = file.refreshMetadata()
        
        // Reload metadata
        await loadMetadata()
    }
    
    /// Copy text to clipboard with user feedback
    @MainActor
    func copyToClipboard(_ text: String, message: String = "Copied to clipboard") {
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Show feedback
        copyConfirmationMessage = message
        showingCopyConfirmation = true
        
        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingCopyConfirmation = false
        }
        
        // Provide haptic feedback if available (macOS 11+)
        #if os(macOS)
        if #available(macOS 11.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        #endif
    }
    
    /// Clears the currently selected file and metadata
    func clearSelection() {
        // Cancel any ongoing metadata extraction without showing an error
        if let task = metadataLoadingTask {
            task.cancel()
            logger.info("Cancelled metadata loading task during clear selection")
            metadataLoadingTask = nil
            currentTaskID = nil
        }
        
        selectedFile = nil
        allMetadata = []
        metadata = []
        error = nil
        
        // Reset selected categories to default when clearing selection
        if let preferences = userPreferences {
            selectedCategories = preferences.defaultCategories
        } else {
            selectedCategories = Set(MetadataCategory.allCases)
        }
    }
    
    /// Connect user preferences to the view model after initialization
    /// - Parameter preferences: The user preferences to observe
    func connectPreferences(_ preferences: UserPreferences) {
        self.userPreferences = preferences
        
        // Update selected categories from preferences
        self.selectedCategories = preferences.defaultCategories
        
        // Set up observations for preference changes
        setupPreferencesObservation()
        
        logger.info("Connected user preferences to AppViewModel")
    }
    
    /// Filter metadata based on search text and selected categories
    @MainActor
    func filterMetadata() {
        guard !allMetadata.isEmpty else {
            metadata = []
            return
        }
        
        var filteredItems = allMetadata
        
        // Filter by selected categories
        if selectedCategories.count < MetadataCategory.allCases.count {
            filteredItems = filteredItems.filter { selectedCategories.contains($0.category) }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            let searchTerms = searchText.lowercased().split(separator: " ")
            
            filteredItems = filteredItems.filter { item in
                let keyMatches = searchTerms.allSatisfy { term in
                    item.key.lowercased().contains(term) ||
                    item.displayName.lowercased().contains(term)
                }
                
                // Also search in string values
                if !keyMatches, let stringValue = item.value as? String {
                    return searchTerms.allSatisfy { stringValue.lowercased().contains($0) }
                }
                
                return keyMatches
            }
        }
        
        // Update the filtered metadata
        metadata = filteredItems
    }
    
    /// Group metadata items by category
    /// - Returns: Dictionary mapping categories to arrays of metadata items
    func groupMetadataByCategory() -> [MetadataCategory: [MetadataItem]] {
        var groupedItems: [MetadataCategory: [MetadataItem]] = [:]
        
        for item in metadata {
            if groupedItems[item.category] == nil {
                groupedItems[item.category] = []
            }
            groupedItems[item.category]?.append(item)
        }
        
        // Sort each category's items
        for (category, items) in groupedItems {
            groupedItems[category] = items.sorted { $0.displayName < $1.displayName }
        }
        
        return groupedItems
    }
    
    /// Get metadata items for a specific category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of metadata items in the requested category
    func metadataForCategory(_ category: MetadataCategory) -> [MetadataItem] {
        return metadata.filter { $0.category == category }
                       .sorted { $0.displayName < $1.displayName }
    }
    
    /// Get the number of items in each category
    /// - Returns: Dictionary mapping categories to counts
    func categoryItemCounts() -> [MetadataCategory: Int] {
        var counts: [MetadataCategory: Int] = [:]
        
        for item in metadata {
            counts[item.category, default: 0] += 1
        }
        
        return counts
    }
    
    /// Get an array of categories that have items
    /// - Returns: Array of metadata categories with non-zero item counts
    func categoriesWithItems() -> [MetadataCategory] {
        let counts = categoryItemCounts()
        return MetadataCategory.allCases.filter { counts[$0, default: 0] > 0 }
                               .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // MARK: - Error Handling
    
    /// Handle an error from file operations
    /// - Parameter error: The error to handle
    @MainActor
    private func handleError(_ error: Error) {
        // Cast to FileAccessError if possible
        if let fileError = error as? FileAccessError {
            self.error = fileError
            
            // Special handling for different error types
            switch fileError {
            case .operationCancelled:
                // User cancelled the operation, just reset the UI state
                isLoading = false
                // No need to show error for user-initiated cancellations
                return
            case .permissionDenied(let url, _):
                // If we have a URL, show the permission request dialog directly
                if let url = url {
                    showPermissionRequestForURL(url)
                    return
                }
                
            case .accessRevoked(let url):
                // If access was revoked, also show the permission request
                if let url = url {
                    showPermissionRequestForURL(url)
                    return
                }
                
            case .unsupportedFileType(let url, _):
                // If we have a URL, show the unsupported file type dialog
                if let url = url {
                    showUnsupportedFileTypeDialog(for: url)
                    return
                }
                
            case .insufficientPermissions:
                // For system-level permissions, we'll let the error view handle
                // directing the user to system preferences
                break
                
            default:
                break
            }
        } else {
            // Otherwise create an unknown error
            self.error = FileAccessError.from(error: error)
        }
        
        // Log the error
        logger.error("Error: \(self.error?.localizedDescription ?? "Unknown error")")
        
        // Show the error alert
        showingError = true
    }
    
    /// Show permission request for a specific URL
    /// - Parameter url: The URL to request permission for
    private func showPermissionRequestForURL(_ url: URL) {
        permissionRequestURL = url
        showingPermissionRequest = true
    }
    
    /// Show unsupported file type dialog for a specific URL
    /// - Parameter url: The URL of the unsupported file
    private func showUnsupportedFileTypeDialog(for url: URL) {
        unsupportedFileURL = url
        showingUnsupportedFileType = true
    }
    
    /// Try to process an unsupported file type anyway
    /// - Parameter url: The URL of the unsupported file
    @MainActor
    func tryProcessUnsupportedFile(_ url: URL) async {
        // Set the flag to allow unsupported file types
        allowUnsupportedFileTypes = true
        
        // Create a basic file reference
        let fileReference = FileReference(url: url)
        
        // Update the selected file
        selectedFile = fileReference
        logger.info("Attempting to process unsupported file: \(fileReference.name)")
        
        // Try to load metadata
        await loadMetadata()
        
        // Reset the flag after attempt
        allowUnsupportedFileTypes = false
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    /// Split an array into chunks of a specified size
    /// - Parameter size: The maximum size for each chunk
    /// - Returns: An array of array chunks
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}