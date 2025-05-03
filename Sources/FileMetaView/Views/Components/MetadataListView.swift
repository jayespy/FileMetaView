import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

/// Preference key for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// View for displaying metadata items in an organized and interactive way
struct MetadataListView: View {
    /// The application view model
    @ObservedObject var viewModel: AppViewModel
    
    /// User preferences
    @EnvironmentObject var preferences: UserPreferences
    
    /// Currently selected metadata item (for detail view or copying)
    @State private var selectedItem: MetadataItem?
    
    /// Set of expanded categories
    @State private var expandedCategories: Set<MetadataCategory> = Set(MetadataCategory.allCases)
    
    /// Selection for contextual menu
    @State private var contextMenuMetadataItem: MetadataItem?
    
    /// Scroll position namespace
    @Namespace private var scrollNamespace
    
    /// Is scroll at the top
    @State private var isScrolledDown: Bool = false
    
    /// Scroll view proxy
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // File info header
            fileInfoHeader
            
            // Metadata content
            if viewModel.metadata.isEmpty {
                EmptyContentView(searchText: viewModel.searchText)
            } else {
                metadataContent
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Metadata content")
            }
        }
    }
    
    /// File information header
    private var fileInfoHeader: some View {
        Group {
            if let file = viewModel.selectedFile {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        if let icon = file.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 36, height: 36)
                                .padding(4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text("\(file.typeDescription) • \(file.formattedSize)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                
                            if let creationDate = file.creationDate {
                                Text("Created: \(formatDate(creationDate))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            metadataSummary
                            
                            // Add path info
                            Text(formatPath(file.url))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Button {
                            Task {
                                await viewModel.refreshMetadata()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("r", modifiers: .command)
                        .help("Refresh metadata")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    
                    // Add a progress indicator for the metadata processing percentage
                    if !viewModel.metadata.isEmpty {
                        let percentage = Double(viewModel.metadata.count) / Double(AppConfiguration.maximumMetadataItems)
                        ProgressView(value: min(percentage, 1.0))
                            .progressViewStyle(.linear)
                            .frame(height: 2)
                    }
                }
            }
        }
    }
    
    /// Format a date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format a file path for display
    private func formatPath(_ url: URL) -> String {
        let path = url.path
        let homePath = NSHomeDirectory()
        
        if path.hasPrefix(homePath) {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }
    
    /// Summary of metadata items
    private var metadataSummary: some View {
        Text("\(viewModel.metadata.count) items")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
    }
    
    /// Metadata content list
    private var metadataContent: some View {
        VStack(spacing: 0) {
            // Controls for expand/collapse all
            HStack {
                Text("Categories")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Expand All") {
                    toggleAllCategories(expanded: true)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
                .help("Expand all categories")
                .accessibilityLabel("Expand all categories")
                
                Text("|")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                Button("Collapse All") {
                    toggleAllCategories(expanded: false)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
                .help("Collapse all categories")
                .accessibilityLabel("Collapse all categories")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Invisible marker for scroll detection
                        Color.clear
                            .frame(width: 0, height: 0)
                            .id(scrollNamespace)
                            
                        // Group by category and display in order
                        ForEach(viewModel.groupMetadataByCategory().keys.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { category in
                            if let items = viewModel.groupMetadataByCategory()[category], !items.isEmpty {
                                metadataSection(for: category, items: items)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .background(
                        // Detect scroll position using GeometryReader
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scrollView")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isScrolledDown = offset < -100
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // Scroll to top button
                    if isScrolledDown {
                        Button {
                            withAnimation(.spring()) {
                                proxy.scrollTo(scrollNamespace, anchor: .top)
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                                .foregroundColor(.accentColor)
                                .background(Circle().fill(Color(NSColor.windowBackgroundColor)))
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
    }
    
    /// Create a section for a category of metadata
    /// - Parameters:
    ///   - category: The metadata category
    ///   - items: The metadata items in this category
    /// - Returns: A section view
    private func metadataSection(for category: MetadataCategory, items: [MetadataItem]) -> some View {
        Section {
            if expandedCategories.contains(category) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        metadataItemRow(item, index: index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItem = (selectedItem == item) ? nil : item
                            }
                    }
                }
                .padding(.top, 2)
            }
        } header: {
            sectionHeader(for: category, itemCount: items.count)
        }
    }
    
    /// Create a section header for a category
    /// - Parameters:
    ///   - category: The metadata category
    ///   - itemCount: The number of items in this category
    /// - Returns: A header view
    private func sectionHeader(for category: MetadataCategory, itemCount: Int) -> some View {
        Button {
            toggleCategory(category)
        } label: {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundColor(category.color)
                    .frame(width: 20)
                
                Text(category.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(itemCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Enhanced with category color
                Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                    .foregroundColor(expandedCategories.contains(category) ? category.color : .secondary)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(category.color.opacity(0.1))
                            .opacity(expandedCategories.contains(category) ? 1 : 0)
                    )
            )
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.2), value: expandedCategories.contains(category))
        }
        .buttonStyle(.plain)
        .help(category.description) // Add tooltip with category description
    }
    
    /// Create a row for a metadata item
    /// - Parameters:
    ///   - item: The metadata item
    ///   - index: The index in the list (for alternating row colors)
    /// - Returns: A row view
    private func metadataItemRow(_ item: MetadataItem, index: Int? = nil) -> some View {
        HStack(alignment: .top) {
            // Key/name
            HStack(spacing: 4) {
                Image(systemName: iconForValueType(item.valueType))
                    .foregroundColor(item.valueType.color)
                    .font(.caption)
                
                Text(item.displayName)
                    .lineLimit(1)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .frame(width: 150, alignment: .leading)
            
            // Value with appropriate formatting
            MetadataValueView(item: item)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Type badge
            Text(item.valueType.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.valueType.color.opacity(0.1))
                )
                .foregroundColor(item.valueType.color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Group {
                if selectedItem == item {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.1))
                } else if preferences.useAlternatingRowColors, let idx = index, idx % 2 == 1 {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.primary.opacity(0.03))
                } else {
                    Color.clear
                }
            }
        )
        .contextMenu {
            metadataContextMenu(for: item)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedItem = (selectedItem == item) ? nil : item
            }
        }
    }
    
    /// Return an appropriate icon for a value type
    private func iconForValueType(_ valueType: MetadataValueType) -> String {
        valueType.iconName
    }
    
    /// Create a context menu for a metadata item
    /// - Parameter item: The metadata item
    /// - Returns: A context menu
    private func metadataContextMenu(for item: MetadataItem) -> some View {
        Group {
            Button("Copy Value") {
                copyToClipboard(item.formattedValue)
            }
            
            Button("Copy Key and Value") {
                copyToClipboard("\(item.displayName): \(item.formattedValue)")
            }
            
            if let url = extractURL(from: item) {
                Divider()
                
                Button("Open URL") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            Divider()
            
            Menu("Value Type") {
                Text(item.valueType.displayName)
                    .font(.caption)
                
                Divider()
                
                Text(item.valueType.description)
                    .font(.caption)
            }
        }
    }
    
    /// Toggle a category's expansion state
    /// - Parameter category: The category to toggle
    private func toggleCategory(_ category: MetadataCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }
    
    /// Toggle all categories at once
    private func toggleAllCategories(expanded: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expanded {
                expandedCategories = Set(MetadataCategory.allCases)
            } else {
                expandedCategories = []
            }
        }
    }
    
    /// Copy text to clipboard with user feedback
    /// - Parameter text: The text to copy
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Show brief user feedback using NSSound
        NSSound.beep()
        
        // Provide haptic feedback if available
        #if os(macOS)
        if #available(macOS 11.0, *) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        #endif
    }
    
    /// Extract a URL from a metadata item if possible
    /// - Parameter item: The metadata item
    /// - Returns: URL if extractable, nil otherwise
    private func extractURL(from item: MetadataItem) -> URL? {
        if item.valueType == .url, let urlString = item.value as? String {
            return URL(string: urlString)
        } else if let url = item.value as? URL {
            return url
        } else if let stringValue = item.value as? String, 
                  (stringValue.hasPrefix("http://") || stringValue.hasPrefix("https://") || 
                   stringValue.hasPrefix("file://")) {
            return URL(string: stringValue)
        }
        return nil
    }
}

/// View for displaying an empty metadata list
struct EmptyContentView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            if !searchText.isEmpty {
                // No search results
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Results")
                    .font(.title)
                    .foregroundColor(.primary)
                
                Text("No metadata items match \"\(searchText)\"")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                // No metadata
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Metadata Found")
                    .font(.title)
                    .foregroundColor(.primary)
                
                Text("No metadata could be extracted from this file")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// View for displaying a metadata value with appropriate formatting
struct MetadataValueView: View {
    let item: MetadataItem
    
    @State private var isExpanded: Bool = false
    @State private var isCopied: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            switch item.valueType {
            case .string:
                textValue
                
            case .url:
                urlValue
                
            case .date:
                dateValue
                
            case .image:
                imageValue
                
            case .array:
                arrayValue
                
            case .dictionary:
                dictionaryValue
                
            case .color:
                colorValue
                
            case .fileSize:
                fileSizeValue
                
            case .duration:
                durationValue
                
            case .boolean:
                booleanValue
                
            case .percentage:
                percentageValue
                
            case .coordinate:
                coordinateValue
                
            case .uti:
                utiValue
                
            default:
                // Default formatting for other types
                Text(item.formattedValue)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isMultiline {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isCopied {
                Text("Copied")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                    )
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                isCopied = false
                            }
                        }
                    }
            }
        }
    }
    
    /// Check if this is likely multiline content
    private var isMultiline: Bool {
        if let stringValue = item.value as? String {
            return stringValue.contains("\n") || stringValue.count > 100
        }
        return false
    }
    
    /// Format for text values
    private var textValue: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(item.formattedValue)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
                
                Spacer(minLength: 8)
                
                // Copy button for text
                if !isExpanded && isMultiline {
                    Button {
                        copyToClipboard(item.formattedValue)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy value")
                }
            }
            
            if isMultiline && !isExpanded {
                Button {
                    withAnimation {
                        isExpanded = true
                    }
                } label: {
                    HStack {
                        Text("Show more...")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        // Count of remaining characters
                        if let stringValue = item.value as? String {
                            let visibleChars = min(stringValue.count, 100)
                            let totalChars = stringValue.count
                            Text("\(visibleChars)/\(totalChars) characters")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if isMultiline && isExpanded {
                HStack {
                    Button {
                        withAnimation {
                            isExpanded = false
                        }
                    } label: {
                        Text("Show less")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    
                    Spacer()
                    
                    // Copy button for expanded text
                    Button {
                        copyToClipboard(item.formattedValue)
                    } label: {
                        Text("Copy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy value")
                }
            }
        }
    }
    
    /// Format for URL values
    private var urlValue: some View {
        VStack(alignment: .leading) {
            HStack {
                if let urlString = item.value as? String, let url = URL(string: urlString) {
                    Link(displayURL(url), destination: url)
                        .lineLimit(isExpanded ? nil : 1)
                } else if let url = item.value as? URL {
                    Link(displayURL(url), destination: url)
                        .lineLimit(isExpanded ? nil : 1)
                } else {
                    Text(item.formattedValue)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Open button for URLs
                if let url = extractURL(from: item) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open URL")
                }
            }
        }
    }
    
    /// Format URL for display
    private func displayURL(_ url: URL) -> String {
        // If it's a file URL, show the path with ~ for home directory
        if url.isFileURL {
            let path = url.path
            let homePath = NSHomeDirectory()
            if path.hasPrefix(homePath) {
                return "~" + path.dropFirst(homePath.count)
            }
            return path
        }
        
        // For web URLs, try to make them more readable
        var urlString = url.absoluteString
        
        // Remove common prefixes
        if urlString.hasPrefix("https://www.") {
            urlString = String(urlString.dropFirst(12))
        } else if urlString.hasPrefix("http://www.") {
            urlString = String(urlString.dropFirst(11))
        } else if urlString.hasPrefix("https://") {
            urlString = String(urlString.dropFirst(8))
        } else if urlString.hasPrefix("http://") {
            urlString = String(urlString.dropFirst(7))
        }
        
        return urlString
    }
    
    /// Format for date values
    private var dateValue: some View {
        if let date = item.value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            
            return Text(formatter.string(from: date))
                .foregroundColor(.primary)
        } else {
            return Text(item.formattedValue)
                .foregroundColor(.secondary)
        }
    }
    
    /// Format for array values
    private var arrayValue: some View {
        VStack(alignment: .leading) {
            if let array = item.value as? [Any] {
                if array.isEmpty {
                    Text("(Empty array)")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(item.formattedValue)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    if !isExpanded && array.count > 3 {
                        Button("Show all \(array.count) items...") {
                            isExpanded = true
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    } else if isExpanded {
                        Button("Show less") {
                            isExpanded = false
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Format for dictionary values
    private var dictionaryValue: some View {
        VStack(alignment: .leading) {
            if let dict = item.value as? [String: Any] {
                if dict.isEmpty {
                    Text("(Empty dictionary)")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(item.formattedValue)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    if !isExpanded && dict.count > 3 {
                        Button("Show all \(dict.count) key-value pairs...") {
                            isExpanded = true
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    } else if isExpanded {
                        Button("Show less") {
                            isExpanded = false
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Format for color values
    private var colorValue: some View {
        HStack {
            if let nsColor = item.value as? NSColor {
                Color(nsColor)
                    .frame(width: 16, height: 16)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary, lineWidth: 0.5)
                    )
                
                Text(item.formattedValue)
                    .foregroundColor(.primary)
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Format for file size values
    private var fileSizeValue: some View {
        if let sizeValue = item.value as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            return Text(formatter.string(fromByteCount: sizeValue))
                .foregroundColor(.primary)
        } else {
            return Text(item.formattedValue)
                .foregroundColor(.primary)
        }
    }
    
    /// Format for duration values
    private var durationValue: some View {
        if let durationValue = item.value as? TimeInterval {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = durationValue >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
            formatter.unitsStyle = .abbreviated
            return Text(formatter.string(from: durationValue) ?? "\(durationValue) seconds")
                .foregroundColor(.primary)
        } else {
            return Text(item.formattedValue)
                .foregroundColor(.primary)
        }
    }
    
    /// Format for boolean values
    private var booleanValue: some View {
        Group {
            if let boolValue = item.value as? Bool {
                HStack {
                    Image(systemName: boolValue ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(boolValue ? .green : .red)
                    
                    Text(boolValue ? "Yes" : "No")
                        .foregroundColor(.primary)
                }
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.primary)
            }
        }
    }
    
    /// Format for image values
    private var imageValue: some View {
        VStack(alignment: .leading) {
            if let dataValue = item.value as? Data, let nsImage = NSImage(data: dataValue) {
                HStack {
                    // Show the actual image
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 100, maxHeight: 100)
                        .cornerRadius(4)
                    
                    // Image info
                    VStack(alignment: .leading) {
                        Text("\(Int(nsImage.size.width)) × \(Int(nsImage.size.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(dataValue.count) bytes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Format for percentage values
    private var percentageValue: some View {
        Group {
            if let doubleValue = item.value as? Double {
                HStack {
                    // Progress bar visualization
                    ProgressView(value: doubleValue / 100.0)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                    
                    Text(String(format: "%.1f%%", doubleValue))
                        .foregroundColor(.primary)
                }
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.primary)
            }
        }
    }
    
    /// Format for coordinate values
    private var coordinateValue: some View {
        Group {
            if let coords = item.value as? CLLocationCoordinate2D {
                VStack(alignment: .leading) {
                    Text(String(format: "Lat: %.6f, Lon: %.6f", coords.latitude, coords.longitude))
                        .foregroundColor(.primary)
                    
                    // Add map link
                    Button("Show on Map") {
                        let mapURL = URL(string: "https://maps.apple.com/?ll=\(coords.latitude),\(coords.longitude)")
                        if let url = mapURL {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            } else if let arrayValue = item.value as? [Double], arrayValue.count >= 2 {
                VStack(alignment: .leading) {
                    Text(String(format: "Lat: %.6f, Lon: %.6f", arrayValue[0], arrayValue[1]))
                        .foregroundColor(.primary)
                    
                    // Add map link
                    Button("Show on Map") {
                        let mapURL = URL(string: "https://maps.apple.com/?ll=\(arrayValue[0]),\(arrayValue[1])")
                        if let url = mapURL {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.primary)
            }
        }
    }
    
    /// Format for UTI values
    private var utiValue: some View {
        Group {
            if let utiString = item.value as? String, let utType = UTType(utiString) {
                VStack(alignment: .leading) {
                    Text(utType.localizedDescription ?? utiString)
                        .foregroundColor(.primary)
                    
                    // Show more technical details
                    HStack {
                        Text("Identifier: \(utiString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let preferredTag = utType.preferredFilenameExtension {
                            Text("Extension: .\(preferredTag)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text(item.formattedValue)
                    .foregroundColor(.primary)
            }
        }
    }
    
    /// Copy text to clipboard and show confirmation
    /// - Parameter text: The text to copy
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Show copied confirmation
        withAnimation {
            isCopied = true
        }
    }
    
    /// Extract a URL from a metadata item if possible
    /// - Parameter item: The metadata item
    /// - Returns: URL if extractable, nil otherwise
    private func extractURL(from item: MetadataItem) -> URL? {
        if item.valueType == .url, let urlString = item.value as? String {
            return URL(string: urlString)
        } else if let url = item.value as? URL {
            return url
        } else if let stringValue = item.value as? String, 
                  (stringValue.hasPrefix("http://") || stringValue.hasPrefix("https://") || 
                   stringValue.hasPrefix("file://")) {
            return URL(string: stringValue)
        }
        return nil
    }
}