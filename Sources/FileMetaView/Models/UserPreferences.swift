import Foundation
import SwiftUI
import Combine

/// Enum defining available application theme options
enum ThemeOption: String, CaseIterable, Identifiable {
    case system = "system" // Follow system appearance
    case light = "light"   // Always use light mode
    case dark = "dark"     // Always use dark mode
    
    var id: String { self.rawValue }
    
    /// Display name for the theme option
    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    /// Get the corresponding ColorScheme or nil for system default
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Enum defining available accent color options
enum AccentColorOption: String, CaseIterable, Identifiable {
    case system = "system"   // Use system accent color
    case blue = "blue"       // Blue accent
    case purple = "purple"   // Purple accent
    case pink = "pink"       // Pink accent
    case red = "red"         // Red accent
    case orange = "orange"   // Orange accent
    case yellow = "yellow"   // Yellow accent
    case green = "green"     // Green accent
    case teal = "teal"       // Teal accent
    case indigo = "indigo"   // Indigo accent
    
    var id: String { self.rawValue }
    
    /// Display name for the accent color option
    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        }
    }
    
    /// Get the corresponding Color
    var color: Color {
        switch self {
        case .system: return Color.accentColor
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return Color(red: 0.0, green: 0.5, blue: 0.5)
        case .indigo: return .indigo
        }
    }
}

/// Enum defining text size options
enum TextSizeOption: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var id: String { self.rawValue }
    
    /// Display name for the text size option
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    /// Get the scaling factor for this text size
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.15
        }
    }
}

/// User configurable preferences for the application
class UserPreferences: ObservableObject {
    // MARK: - Dependencies
    
    /// UserDefaults manager for persistence
    private let defaults = UserDefaultsManager.shared
    
    // MARK: - Published Properties
    
    /// Default categories to display when selecting a file
    @Published var defaultCategories: Set<MetadataCategory> {
        didSet {
            saveDefaultCategories()
        }
    }
    
    /// Whether to show all metadata or apply filtering
    @Published var showAllMetadata: Bool {
        didSet {
            defaults.setBool(showAllMetadata, forKey: UserDefaultsManager.Keys.showAllMetadataKey)
        }
    }
    
    /// Theme/appearance option
    @Published var themeOption: ThemeOption {
        didSet {
            defaults.setString(themeOption.rawValue, forKey: UserDefaultsManager.Keys.themeOptionKey)
        }
    }
    
    /// Accent color option
    @Published var accentColorOption: AccentColorOption {
        didSet {
            defaults.setString(accentColorOption.rawValue, forKey: UserDefaultsManager.Keys.accentColorKey)
        }
    }
    
    /// Text size option
    @Published var textSizeOption: TextSizeOption {
        didSet {
            defaults.setString(textSizeOption.rawValue, forKey: UserDefaultsManager.Keys.textSizeKey)
        }
    }
    
    /// Whether to use alternating row colors in lists
    @Published var useAlternatingRowColors: Bool {
        didSet {
            defaults.setBool(useAlternatingRowColors, forKey: UserDefaultsManager.Keys.useAlternatingRowColorsKey)
        }
    }
    
    /// Maximum number of metadata items to show
    @Published var maxMetadataItems: Int {
        didSet {
            // Ensure value is within allowed range
            if maxMetadataItems < AppConfiguration.minimumMetadataItems {
                maxMetadataItems = AppConfiguration.minimumMetadataItems
            } else if maxMetadataItems > AppConfiguration.maximumMetadataItems {
                maxMetadataItems = AppConfiguration.maximumMetadataItems
            }
            defaults.setInt(maxMetadataItems, forKey: UserDefaultsManager.Keys.maxMetadataItemsKey)
        }
    }
    
    /// Recently accessed files
    @Published var recentFiles: [URL] {
        didSet {
            // Limit number of recent files to 10
            if recentFiles.count > 10 {
                recentFiles = Array(recentFiles.prefix(10))
            }
            
            _ = defaults.setURLs(recentFiles, forKey: UserDefaultsManager.Keys.recentFilesKey)
        }
    }
    
    /// Whether to automatically refresh metadata when file changes
    @Published var autoRefreshMetadata: Bool {
        didSet {
            defaults.setBool(autoRefreshMetadata, forKey: UserDefaultsManager.Keys.autoRefreshKey)
        }
    }
    
    /// Whether to group metadata by categories
    @Published var groupByCategories: Bool {
        didSet {
            defaults.setBool(groupByCategories, forKey: UserDefaultsManager.Keys.groupByCategories)
        }
    }
    
    /// Whether to show the file information section
    @Published var showFileInfoSection: Bool {
        didSet {
            defaults.setBool(showFileInfoSection, forKey: UserDefaultsManager.Keys.showFileInfoSection)
        }
    }
    
    /// The last used view in the application (for restoring state)
    @Published var lastUsedView: String? {
        didSet {
            defaults.setString(lastUsedView, forKey: UserDefaultsManager.Keys.lastUsedViewKey)
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize with default values or load from UserDefaults
    init() {
        // Set default values first
        self.defaultCategories = Set(MetadataCategory.allCases)
        self.showAllMetadata = true
        self.themeOption = .system
        self.accentColorOption = .system
        self.textSizeOption = .medium
        self.useAlternatingRowColors = true
        self.maxMetadataItems = AppConfiguration.maximumMetadataItems
        self.recentFiles = []
        self.autoRefreshMetadata = true
        self.groupByCategories = true
        self.showFileInfoSection = true
        self.lastUsedView = nil
        
        // Then load from UserDefaults if available
        self.loadFromUserDefaults()
    }
    
    // MARK: - Private Methods
    
    /// Load preferences from UserDefaults
    private func loadFromUserDefaults() {
        // Load default categories
        let categoryStrings = defaults.getStringArray(forKey: UserDefaultsManager.Keys.defaultCategoriesKey)
        if !categoryStrings.isEmpty {
            let savedCategories = categoryStrings.compactMap { rawValue -> MetadataCategory? in
                return MetadataCategory(rawValue: rawValue)
            }
            
            // Only use saved categories if at least one valid category was found
            if !savedCategories.isEmpty {
                self.defaultCategories = Set(savedCategories)
            }
        }
        
        // Load show all metadata setting
        self.showAllMetadata = defaults.getBool(forKey: UserDefaultsManager.Keys.showAllMetadataKey, defaultValue: true)
        
        // Load theme option
        if let themeString = defaults.getString(forKey: UserDefaultsManager.Keys.themeOptionKey),
           let savedTheme = ThemeOption(rawValue: themeString) {
            self.themeOption = savedTheme
        }
        
        // Load accent color option
        if let accentColorString = defaults.getString(forKey: UserDefaultsManager.Keys.accentColorKey),
           let savedAccentColor = AccentColorOption(rawValue: accentColorString) {
            self.accentColorOption = savedAccentColor
        }
        
        // Load text size option
        if let textSizeString = defaults.getString(forKey: UserDefaultsManager.Keys.textSizeKey),
           let savedTextSize = TextSizeOption(rawValue: textSizeString) {
            self.textSizeOption = savedTextSize
        }
        
        // Load alternating row colors setting
        self.useAlternatingRowColors = defaults.getBool(forKey: UserDefaultsManager.Keys.useAlternatingRowColorsKey, defaultValue: true)
        
        // Load max metadata items
        let savedMax = defaults.getInt(forKey: UserDefaultsManager.Keys.maxMetadataItemsKey, defaultValue: AppConfiguration.maximumMetadataItems)
        // Ensure value is within allowed range
        if savedMax >= AppConfiguration.minimumMetadataItems && savedMax <= AppConfiguration.maximumMetadataItems {
            self.maxMetadataItems = savedMax
        }
        
        // Load recent files
        self.recentFiles = defaults.getURLs(forKey: UserDefaultsManager.Keys.recentFilesKey)
        
        // Load auto refresh setting
        self.autoRefreshMetadata = defaults.getBool(forKey: UserDefaultsManager.Keys.autoRefreshKey, defaultValue: true)
        
        // Load group by categories setting
        self.groupByCategories = defaults.getBool(forKey: UserDefaultsManager.Keys.groupByCategories, defaultValue: true)
        
        // Load show file info section setting
        self.showFileInfoSection = defaults.getBool(forKey: UserDefaultsManager.Keys.showFileInfoSection, defaultValue: true)
        
        // Load last used view
        self.lastUsedView = defaults.getString(forKey: UserDefaultsManager.Keys.lastUsedViewKey)
    }
    
    /// Save default categories to UserDefaults
    private func saveDefaultCategories() {
        let categoryStrings = defaultCategories.map { $0.rawValue }
        defaults.setStringArray(categoryStrings, forKey: UserDefaultsManager.Keys.defaultCategoriesKey)
    }
    
    // MARK: - Public Methods
    
    /// Add a file to recent files list
    /// - Parameter url: The URL to add
    func addRecentFile(_ url: URL) {
        // Remove the URL if it already exists in the list
        recentFiles.removeAll { $0 == url }
        
        // Add the URL to the beginning of the list
        recentFiles.insert(url, at: 0)
    }
    
    /// Remove a file from recent files list
    /// - Parameter url: The URL to remove
    func removeRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
    }
    
    /// Clear all recent files
    func clearRecentFiles() {
        recentFiles = []
    }
    
    /// Reset all preferences to default values
    func resetToDefaults() {
        defaultCategories = Set(MetadataCategory.allCases)
        showAllMetadata = true
        themeOption = .system
        accentColorOption = .system
        textSizeOption = .medium
        useAlternatingRowColors = true
        maxMetadataItems = AppConfiguration.maximumMetadataItems
        recentFiles = []
        autoRefreshMetadata = true
        groupByCategories = true
        showFileInfoSection = true
        lastUsedView = nil
    }
    
    /// Export settings to JSON
    /// - Returns: A JSON string of the settings or nil if export fails
    func exportSettingsToJSON() -> String? {
        // Create a dictionary for settings that can be exported
        let exportableSettings: [String: Any] = [
            "themeOption": themeOption.rawValue,
            "accentColorOption": accentColorOption.rawValue,
            "textSizeOption": textSizeOption.rawValue,
            "useAlternatingRowColors": useAlternatingRowColors,
            "showAllMetadata": showAllMetadata,
            "maxMetadataItems": maxMetadataItems,
            "defaultCategories": defaultCategories.map { $0.rawValue },
            "autoRefreshMetadata": autoRefreshMetadata,
            "groupByCategories": groupByCategories,
            "showFileInfoSection": showFileInfoSection
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: exportableSettings, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to export settings: \(error)")
            return nil
        }
    }
    
    /// Import settings from JSON
    /// - Parameter json: The JSON string containing settings
    /// - Returns: Success or failure
    func importSettingsFromJSON(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8) else {
            return false
        }
        
        do {
            guard let settings = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return false
            }
            
            // Apply the imported settings
            if let themeString = settings["themeOption"] as? String, 
               let theme = ThemeOption(rawValue: themeString) {
                self.themeOption = theme
            }
            
            if let accentColorString = settings["accentColorOption"] as? String,
               let accentColor = AccentColorOption(rawValue: accentColorString) {
                self.accentColorOption = accentColor
            }
            
            if let textSizeString = settings["textSizeOption"] as? String,
               let textSize = TextSizeOption(rawValue: textSizeString) {
                self.textSizeOption = textSize
            }
            
            if let alternatingRows = settings["useAlternatingRowColors"] as? Bool {
                self.useAlternatingRowColors = alternatingRows
            }
            
            if let showAll = settings["showAllMetadata"] as? Bool {
                self.showAllMetadata = showAll
            }
            
            if let maxItems = settings["maxMetadataItems"] as? Int {
                self.maxMetadataItems = maxItems
            }
            
            if let categories = settings["defaultCategories"] as? [String] {
                let savedCategories = categories.compactMap { MetadataCategory(rawValue: $0) }
                if !savedCategories.isEmpty {
                    self.defaultCategories = Set(savedCategories)
                }
            }
            
            if let autoRefresh = settings["autoRefreshMetadata"] as? Bool {
                self.autoRefreshMetadata = autoRefresh
            }
            
            if let groupBy = settings["groupByCategories"] as? Bool {
                self.groupByCategories = groupBy
            }
            
            if let showFileInfo = settings["showFileInfoSection"] as? Bool {
                self.showFileInfoSection = showFileInfo
            }
            
            return true
        } catch {
            print("Failed to import settings: \(error)")
            return false
        }
    }
}