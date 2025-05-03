import SwiftUI
import UniformTypeIdentifiers

/// View for managing user preferences
struct PreferencesView: View {
    /// The user preferences instance
    @ObservedObject var preferences: UserPreferences
    
    /// Environment presentation mode for dismissing the view
    @Environment(\.presentationMode) var presentationMode
    
    /// Temporary state for editing preferences
    @State private var tempCategories: Set<MetadataCategory>
    @State private var tempShowAllMetadata: Bool
    @State private var tempThemeOption: ThemeOption
    @State private var tempAccentColorOption: AccentColorOption
    @State private var tempTextSizeOption: TextSizeOption
    @State private var tempUseAlternatingRowColors: Bool
    @State private var tempMaxMetadataItems: Int
    @State private var tempAutoRefreshMetadata: Bool
    @State private var tempGroupByCategories: Bool
    @State private var tempShowFileInfoSection: Bool
    
    /// State for showing import/export dialogs
    @State private var isShowingImportDialog = false
    @State private var isShowingExportDialog = false
    @State private var isShowingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var importSuccess = false
    
    /// Initialize with the user preferences
    init(preferences: UserPreferences) {
        self.preferences = preferences
        
        // Initialize temp state with current preference values
        _tempCategories = State(initialValue: preferences.defaultCategories)
        _tempShowAllMetadata = State(initialValue: preferences.showAllMetadata)
        _tempThemeOption = State(initialValue: preferences.themeOption)
        _tempAccentColorOption = State(initialValue: preferences.accentColorOption)
        _tempTextSizeOption = State(initialValue: preferences.textSizeOption)
        _tempUseAlternatingRowColors = State(initialValue: preferences.useAlternatingRowColors)
        _tempMaxMetadataItems = State(initialValue: preferences.maxMetadataItems)
        _tempAutoRefreshMetadata = State(initialValue: preferences.autoRefreshMetadata)
        _tempGroupByCategories = State(initialValue: preferences.groupByCategories)
        _tempShowFileInfoSection = State(initialValue: preferences.showFileInfoSection)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and buttons
            HStack {
                Text("Preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Main preference content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Appearance Settings Section
                    GroupBox(label: SectionLabel(title: "Appearance", systemImage: "paintpalette")) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Theme selection with preview
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Color Theme")
                                    .font(.headline)
                                
                                Picker("", selection: $tempThemeOption) {
                                    ForEach(ThemeOption.allCases) { option in
                                        Text(option.displayName).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                
                                // Theme preview
                                ThemePreview(
                                    theme: tempThemeOption,
                                    accentColor: tempAccentColorOption,
                                    useAlternatingRows: tempUseAlternatingRowColors
                                )
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            Divider()
                            
                            // Accent color selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Accent Color")
                                    .font(.headline)
                                
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 40), spacing: 8)
                                ], spacing: 8) {
                                    ForEach(AccentColorOption.allCases) { colorOption in
                                        ColorButton(
                                            color: colorOption.color,
                                            isSelected: tempAccentColorOption == colorOption,
                                            label: colorOption == .system ? "S" : nil
                                        ) {
                                            tempAccentColorOption = colorOption
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Text size options
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Text Size")
                                    .font(.headline)
                                
                                Picker("", selection: $tempTextSizeOption) {
                                    ForEach(TextSizeOption.allCases) { option in
                                        Text(option.displayName).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                
                                // Text size preview
                                HStack(spacing: 20) {
                                    TextSizePreview(size: .small, isSelected: tempTextSizeOption == .small)
                                    TextSizePreview(size: .medium, isSelected: tempTextSizeOption == .medium)
                                    TextSizePreview(size: .large, isSelected: tempTextSizeOption == .large)
                                }
                                .padding(.top, 4)
                            }
                            
                            Divider()
                            
                            // Alternating row colors toggle
                            PreferenceToggle(
                                isOn: $tempUseAlternatingRowColors,
                                title: "Use Alternating Row Colors",
                                description: "Display metadata items with alternating background colors for better readability"
                            )
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // General Settings Section
                    GroupBox(label: SectionLabel(title: "General Settings", systemImage: "gearshape")) {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            // Metadata limit slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Maximum Metadata Items")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text("\(tempMaxMetadataItems)")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                
                                Slider(
                                    value: Binding(
                                        get: { Double(tempMaxMetadataItems) },
                                        set: { tempMaxMetadataItems = Int($0) }
                                    ),
                                    in: Double(AppConfiguration.minimumMetadataItems)...Double(AppConfiguration.maximumMetadataItems),
                                    step: 1
                                )
                                
                                Text("Show up to \(tempMaxMetadataItems) metadata items for each file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Toggle switches for boolean preferences
                            PreferenceToggle(
                                isOn: $tempShowAllMetadata,
                                title: "Show All Metadata",
                                description: "Display all available metadata instead of just commonly used fields"
                            )
                            
                            PreferenceToggle(
                                isOn: $tempAutoRefreshMetadata,
                                title: "Auto-Refresh Metadata",
                                description: "Automatically refresh metadata when file changes are detected"
                            )
                            
                            PreferenceToggle(
                                isOn: $tempGroupByCategories,
                                title: "Group by Categories",
                                description: "Organize metadata items into logical categories"
                            )
                            
                            PreferenceToggle(
                                isOn: $tempShowFileInfoSection,
                                title: "Show File Information",
                                description: "Display a summary of the file at the top of the metadata list"
                            )
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Default Categories Section
                    GroupBox(label: SectionLabel(title: "Default Categories", systemImage: "folder.badge.gear")) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Select which metadata categories should be shown by default when viewing a file")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            // Category checkboxes in a grid layout
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(MetadataCategory.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { category in
                                    CategoryToggle(
                                        category: category,
                                        isSelected: tempCategories.contains(category),
                                        action: {
                                            toggleCategory(category)
                                        }
                                    )
                                }
                            }
                            
                            // Select/Deselect All buttons
                            HStack {
                                Button("Select All") {
                                    tempCategories = Set(MetadataCategory.allCases)
                                }
                                .disabled(tempCategories.count == MetadataCategory.allCases.count)
                                
                                Spacer()
                                
                                Button("Deselect All") {
                                    // Keep at least one category selected
                                    if tempCategories.count > 1 {
                                        // Keep only basic category
                                        tempCategories = [.basic]
                                    }
                                }
                                .disabled(tempCategories.count <= 1)
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Import/Export & Reset Section
                    GroupBox(label: SectionLabel(title: "Settings Management", systemImage: "arrow.up.arrow.down.circle")) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Import, export or reset your preferences")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            HStack(spacing: 16) {
                                Button {
                                    isShowingImportDialog = true
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Import Settings")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button {
                                    isShowingExportDialog = true
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Export Settings")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button {
                                resetPreferences()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset to Defaults")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Information section
                    VStack(alignment: .center, spacing: 8) {
                        Text("FileMetaView \(AppConfiguration.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Preferences are automatically saved when you close this window")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .padding(.vertical)
            }
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $isShowingImportDialog) {
            ImportSettingsView { jsonString in
                let result = preferences.importSettingsFromJSON(jsonString)
                importSuccess = result
                importAlertMessage = result ? 
                    "Settings imported successfully. Restart the app for all changes to take effect." : 
                    "Failed to import settings. The file may be invalid or corrupt."
                isShowingImportAlert = true
                
                // Update temp values if import was successful
                if result {
                    updateTempValues()
                }
            }
        }
        .fileExporter(
            isPresented: $isShowingExportDialog,
            document: SettingsDocument(jsonString: preferences.exportSettingsToJSON() ?? "{}"),
            contentType: .json,
            defaultFilename: "FileMetaView_Settings"
        ) { result in
            // Export handling is done by the system
        }
        .alert(
            importSuccess ? "Import Successful" : "Import Failed",
            isPresented: $isShowingImportAlert
        ) {
            Button("OK") {}
        } message: {
            Text(importAlertMessage)
        }
    }
    
    /// Toggle a category's selection state
    private func toggleCategory(_ category: MetadataCategory) {
        if tempCategories.contains(category) {
            // Don't allow deselecting if it's the only selected category
            if tempCategories.count > 1 {
                tempCategories.remove(category)
            }
        } else {
            tempCategories.insert(category)
        }
    }
    
    /// Save changes to user preferences
    private func saveChanges() {
        preferences.defaultCategories = tempCategories
        preferences.showAllMetadata = tempShowAllMetadata
        preferences.themeOption = tempThemeOption
        preferences.accentColorOption = tempAccentColorOption
        preferences.textSizeOption = tempTextSizeOption
        preferences.useAlternatingRowColors = tempUseAlternatingRowColors
        preferences.maxMetadataItems = tempMaxMetadataItems
        preferences.autoRefreshMetadata = tempAutoRefreshMetadata
        preferences.groupByCategories = tempGroupByCategories
        preferences.showFileInfoSection = tempShowFileInfoSection
    }
    
    /// Reset preferences to default values
    private func resetPreferences() {
        preferences.resetToDefaults()
        updateTempValues()
    }
    
    /// Update temporary values from current preferences
    private func updateTempValues() {
        tempCategories = preferences.defaultCategories
        tempShowAllMetadata = preferences.showAllMetadata
        tempThemeOption = preferences.themeOption
        tempAccentColorOption = preferences.accentColorOption
        tempTextSizeOption = preferences.textSizeOption
        tempUseAlternatingRowColors = preferences.useAlternatingRowColors
        tempMaxMetadataItems = preferences.maxMetadataItems
        tempAutoRefreshMetadata = preferences.autoRefreshMetadata
        tempGroupByCategories = preferences.groupByCategories
        tempShowFileInfoSection = preferences.showFileInfoSection
    }
}

// MARK: - Helper Views

/// A section label with icon
struct SectionLabel: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
                .fontWeight(.semibold)
        }
    }
}

/// A toggle for boolean preferences
struct PreferenceToggle: View {
    @Binding var isOn: Bool
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 26) // Align with toggle text
        }
        .padding(.vertical, 4)
    }
}

/// A toggle button for category selection
struct CategoryToggle: View {
    let category: MetadataCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? category.color : .secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: category.iconName)
                        .foregroundColor(category.color)
                    
                    Text(category.displayName)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Document struct for exporting settings
struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var jsonString: String
    
    init(jsonString: String) {
        self.jsonString = jsonString
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.jsonString = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = jsonString.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

/// View for importing settings from JSON
struct ImportSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var jsonText = ""
    
    let onImport: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import Settings")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Import") {
                    onImport(jsonText)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste your settings JSON below:")
                    .font(.subheadline)
                
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                Text("Note: Importing settings will overwrite your current preferences")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Theme Preview Components

/// A preview of the selected theme
struct ThemePreview: View {
    let theme: ThemeOption
    let accentColor: AccentColorOption
    let useAlternatingRows: Bool
    
    var body: some View {
        let backgroundColor: Color = {
            switch theme {
            case .system:
                return Color(NSColor.windowBackgroundColor)
            case .light:
                return Color(.white)
            case .dark:
                return Color(.darkGray)
            }
        }()
        
        let textColor: Color = {
            switch theme {
            case .system, .light:
                return Color(.black)
            case .dark:
                return Color(.white)
            }
        }()
        
        let secondaryTextColor: Color = {
            switch theme {
            case .system, .light:
                return Color(.darkGray)
            case .dark:
                return Color(.lightGray)
            }
        }()
        
        return VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(accentColor.color)
                
                Text("Theme Preview")
                    .foregroundColor(textColor)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("FileMetaView")
                    .foregroundColor(secondaryTextColor)
                    .font(.caption)
            }
            .padding(8)
            .background(backgroundColor)
            
            Divider()
            
            // Content with sample metadata items
            VStack(spacing: 0) {
                MetadataPreviewRow(
                    name: "File Size",
                    value: "1.24 MB",
                    iconName: "arrow.up.arrow.down",
                    color: accentColor.color,
                    textColor: textColor,
                    useAlternatingBackground: useAlternatingRows,
                    isAlternate: false
                )
                
                MetadataPreviewRow(
                    name: "Created Date",
                    value: "April 30, 2025",
                    iconName: "calendar",
                    color: accentColor.color,
                    textColor: textColor,
                    useAlternatingBackground: useAlternatingRows,
                    isAlternate: true
                )
                
                MetadataPreviewRow(
                    name: "File Type",
                    value: "Document",
                    iconName: "doc",
                    color: accentColor.color,
                    textColor: textColor,
                    useAlternatingBackground: useAlternatingRows,
                    isAlternate: false
                )
            }
        }
        .background(backgroundColor)
    }
}

/// A single row in the metadata preview
struct MetadataPreviewRow: View {
    let name: String
    let value: String
    let iconName: String
    let color: Color
    let textColor: Color
    let useAlternatingBackground: Bool
    let isAlternate: Bool
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(name)
                .foregroundColor(textColor)
            
            Spacer()
            
            Text(value)
                .foregroundColor(textColor.opacity(0.7))
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            useAlternatingBackground && isAlternate ?
                Color.primary.opacity(0.05) : Color.clear
        )
    }
}

/// A button for selecting a color option
struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let label: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color == .yellow || color == .green ? .black : .white)
                }
                
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: 30, height: 30)
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : Color.clear, radius: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// A preview of text size
struct TextSizePreview: View {
    let size: TextSizeOption
    let isSelected: Bool
    
    var body: some View {
        Text("Aa")
            .font(.system(size: 14 * size.scaleFactor))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .fontWeight(isSelected ? .bold : .regular)
            .frame(width: 40, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
    }
}

// MARK: - Previews

// Preview disabled for compatibility
/*
struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView(preferences: UserPreferences())
    }
}
*/
