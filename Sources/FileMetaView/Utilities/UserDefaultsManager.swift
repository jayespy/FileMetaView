import Foundation
import os.log

/// A manager for handling persistent application settings using UserDefaults
class UserDefaultsManager {
    // MARK: - Properties
    
    /// Shared instance for singleton access
    static let shared = UserDefaultsManager()
    
    /// The UserDefaults suite to use
    private let defaults: UserDefaults
    
    /// Logger for the UserDefaultsManager
    private let logger = Logger(subsystem: "com.example.FileMetaView", category: "UserDefaultsManager")
    
    /// App version when settings were last saved (for migration)
    private(set) var lastSavedVersion: String?
    
    // MARK: - Keys
    
    /// Keys for settings stored in UserDefaults
    enum Keys {
        // App state
        static let lastSavedVersionKey = "lastSavedVersion"
        static let lastUsedViewKey = "lastUsedView"
        
        // General preferences
        static let defaultCategoriesKey = "defaultCategories"
        static let showAllMetadataKey = "showAllMetadata"
        static let themeOptionKey = "themeOption"
        static let accentColorKey = "accentColor"
        static let textSizeKey = "textSize"
        static let useAlternatingRowColorsKey = "useAlternatingRowColors"
        static let maxMetadataItemsKey = "maxMetadataItems"
        static let recentFilesKey = "recentFiles"
        static let autoRefreshKey = "autoRefresh"
        static let groupByCategories = "groupByCategories"
        static let showFileInfoSection = "showFileInfoSection"
        
        // Specialized settings groups (for future expansion)
        static let viewSettingsPrefix = "view."
        static let fileTypeSettingsPrefix = "fileType."
        static let extractorSettingsPrefix = "extractor."
    }
    
    // MARK: - Initialization
    
    /// Initialize with the standard UserDefaults
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        // Check last saved version
        lastSavedVersion = getString(forKey: Keys.lastSavedVersionKey)
        
        // If version has changed, potentially handle migrations
        if lastSavedVersion != AppConfiguration.version {
            handleVersionChange(from: lastSavedVersion, to: AppConfiguration.version)
        }
    }
    
    // MARK: - Basic Operations
    
    /// Get a string value from UserDefaults
    /// - Parameters:
    ///   - key: The key to retrieve
    ///   - defaultValue: Default value if key not found
    /// - Returns: The stored string or defaultValue
    func getString(forKey key: String, defaultValue: String? = nil) -> String? {
        if let value = defaults.string(forKey: key) {
            return value
        }
        return defaultValue
    }
    
    /// Set a string value in UserDefaults
    /// - Parameters:
    ///   - value: The string to store
    ///   - key: The key to store it under
    func setString(_ value: String?, forKey key: String) {
        if let value = value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
    
    /// Get a boolean value from UserDefaults
    /// - Parameters:
    ///   - key: The key to retrieve
    ///   - defaultValue: Default value if key not found
    /// - Returns: The stored boolean or defaultValue
    func getBool(forKey key: String, defaultValue: Bool = false) -> Bool {
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }
        return defaultValue
    }
    
    /// Set a boolean value in UserDefaults
    /// - Parameters:
    ///   - value: The boolean to store
    ///   - key: The key to store it under
    func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    /// Get an integer value from UserDefaults
    /// - Parameters:
    ///   - key: The key to retrieve
    ///   - defaultValue: Default value if key not found
    /// - Returns: The stored integer or defaultValue
    func getInt(forKey key: String, defaultValue: Int = 0) -> Int {
        if defaults.object(forKey: key) != nil {
            return defaults.integer(forKey: key)
        }
        return defaultValue
    }
    
    /// Set an integer value in UserDefaults
    /// - Parameters:
    ///   - value: The integer to store
    ///   - key: The key to store it under
    func setInt(_ value: Int, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    /// Get a double value from UserDefaults
    /// - Parameters:
    ///   - key: The key to retrieve
    ///   - defaultValue: Default value if key not found
    /// - Returns: The stored double or defaultValue
    func getDouble(forKey key: String, defaultValue: Double = 0.0) -> Double {
        if defaults.object(forKey: key) != nil {
            return defaults.double(forKey: key)
        }
        return defaultValue
    }
    
    /// Set a double value in UserDefaults
    /// - Parameters:
    ///   - value: The double to store
    ///   - key: The key to store it under
    func setDouble(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    /// Get Data from UserDefaults
    /// - Parameters:
    ///   - key: The key to retrieve
    /// - Returns: The stored Data or nil
    func getData(forKey key: String) -> Data? {
        return defaults.data(forKey: key)
    }
    
    /// Set Data in UserDefaults
    /// - Parameters:
    ///   - value: The Data to store
    ///   - key: The key to store it under
    func setData(_ value: Data?, forKey key: String) {
        if let value = value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
    
    /// Get a string array from UserDefaults
    /// - Parameters:
    ///   - key: The key to retrieve
    /// - Returns: The stored string array or empty array
    func getStringArray(forKey key: String) -> [String] {
        return defaults.stringArray(forKey: key) ?? []
    }
    
    /// Set a string array in UserDefaults
    /// - Parameters:
    ///   - value: The string array to store
    ///   - key: The key to store it under
    func setStringArray(_ value: [String], forKey key: String) {
        defaults.set(value, forKey: key)
    }
    
    // MARK: - Complex Type Handling
    
    /// Save a Codable object to UserDefaults
    /// - Parameters:
    ///   - object: The object to save
    ///   - key: The key to save under
    /// - Returns: Success or failure
    func setCodable<T: Codable>(_ object: T, forKey key: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(object)
            defaults.set(data, forKey: key)
            return true
        } catch {
            logger.error("Failed to encode object for key \(key): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get a Codable object from UserDefaults
    /// - Parameters:
    ///   - type: The type to decode
    ///   - key: The key to retrieve
    /// - Returns: The decoded object or nil
    func getCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Failed to decode object for key \(key): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Save an array of URLs to UserDefaults as secure bookmarks
    /// - Parameters:
    ///   - urls: The URLs to save
    ///   - key: The key to save under
    /// - Returns: Success or failure
    func setURLs(_ urls: [URL], forKey key: String) -> Bool {
        // Convert URLs to secure bookmarks
        let bookmarks = urls.compactMap { url -> Data? in
            do {
                return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            } catch {
                logger.error("Failed to create bookmark for \(url.path): \(error.localizedDescription)")
                return nil
            }
        }
        
        // Save bookmarks to UserDefaults
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: true)
            defaults.set(data, forKey: key)
            return true
        } catch {
            logger.error("Failed to save URLs for key \(key): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get an array of URLs from UserDefaults
    /// - Parameter key: The key to retrieve
    /// - Returns: The array of URLs or empty array
    func getURLs(forKey key: String) -> [URL] {
        guard let bookmarksData = defaults.data(forKey: key) else {
            return []
        }
        
        do {
            if let bookmarks = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: bookmarksData) as? [Data] {
                return bookmarks.compactMap { bookmark -> URL? in
                    var isStale = false
                    do {
                        return try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                    } catch {
                        logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
                        return nil
                    }
                }
            }
        } catch {
            logger.error("Failed to load URLs for key \(key): \(error.localizedDescription)")
        }
        
        return []
    }
    
    // MARK: - Management Functions
    
    /// Check if a key exists in UserDefaults
    /// - Parameter key: The key to check
    /// - Returns: Whether the key exists
    func hasKey(_ key: String) -> Bool {
        return defaults.object(forKey: key) != nil
    }
    
    /// Remove a key from UserDefaults
    /// - Parameter key: The key to remove
    func removeKey(_ key: String) {
        defaults.removeObject(forKey: key)
    }
    
    /// Reset all user defaults (dangerous!)
    func resetAllSettings() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        
        // Save current version after reset
        setString(AppConfiguration.version, forKey: Keys.lastSavedVersionKey)
    }
    
    /// Reset a specific group of settings
    /// - Parameter prefix: The prefix for keys to reset
    func resetSettingsGroup(withPrefix prefix: String) {
        let allKeys = defaults.dictionaryRepresentation().keys
        let matchingKeys = allKeys.filter { $0.hasPrefix(prefix) }
        
        for key in matchingKeys {
            defaults.removeObject(forKey: key)
        }
    }
    
    /// Export all settings to a dictionary
    /// - Returns: A dictionary of all settings
    func exportSettings() -> [String: Any] {
        return defaults.dictionaryRepresentation()
    }
    
    /// Import settings from a dictionary
    /// - Parameter settings: The settings to import
    func importSettings(_ settings: [String: Any]) {
        for (key, value) in settings {
            defaults.set(value, forKey: key)
        }
    }
    
    // MARK: - Version Management
    
    /// Handle changes in app version for potential settings migration
    /// - Parameters:
    ///   - oldVersion: The previous version or nil if first launch
    ///   - newVersion: The current app version
    private func handleVersionChange(from oldVersion: String?, to newVersion: String) {
        // Log version change
        if let oldVersion = oldVersion {
            logger.info("App version changed from \(oldVersion) to \(newVersion)")
            
            // Future version-specific migrations could go here
            // Example:
            // if oldVersion.starts(with: "1.0") && newVersion.starts(with: "1.1") {
            //     migrateSettingsFrom10To11()
            // }
        } else {
            logger.info("First launch of version \(newVersion)")
        }
        
        // Update the stored version
        setString(newVersion, forKey: Keys.lastSavedVersionKey)
        lastSavedVersion = newVersion
    }
}