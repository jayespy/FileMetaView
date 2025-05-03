import Foundation

/// Application configuration settings
enum AppConfiguration {
    /// The current version of the application
    static let version = "1.0.0"
    
    /// The minimum number of metadata items to display
    static let minimumMetadataItems = 5
    
    /// The maximum number of metadata items to display 
    static let maximumMetadataItems = 30
    
    /// Default window size
    static let defaultWindowWidth: Double = 800
    static let defaultWindowHeight: Double = 600
    
    /// Time interval for metadata refresh operations (in seconds)
    static let metadataRefreshInterval: TimeInterval = 2.0
    
    #if DEBUG
    /// Debug mode settings
    static let enableVerboseLogging = true
    static let enableDebugMenu = true
    #else
    static let enableVerboseLogging = false
    static let enableDebugMenu = false
    #endif
}
