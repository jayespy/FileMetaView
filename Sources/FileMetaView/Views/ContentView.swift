import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    /// Main view model for the application
    @StateObject var viewModel: AppViewModel
    
    /// State for controlling search field focus - proper FocusState usage
    @FocusState private var searchFieldFocused: Bool
    
    /// State for tracking if the sidebar is open (for responsive design)
    @State private var isSidebarOpen = true
    
    var body: some View {
        HSplitView {
            // Left sidebar: File selection area
            VStack(spacing: 0) {
                FileSelectionView(viewModel: viewModel)
                    .padding()
                    .accessibilityLabel("File Selection Area")
                
                // Add search field in the sidebar
                if viewModel.selectedFile != nil {
                    Divider()
                    
                    VStack(spacing: 12) {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            
                            // Simple TextField with proper focus management
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                
                                // Use standard TextField with proper focus state
                                TextField("Search metadata", text: $viewModel.searchText)
                                    .focused($searchFieldFocused)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit {
                                        // Don't clear focus on submit to avoid focus loss
                                    }
                                    .onTapGesture {
                                        // This is redundant with .focused but added for emphasis
                                        searchFieldFocused = true
                                    }
                                
                                if !viewModel.searchText.isEmpty {
                                    Button {
                                        viewModel.searchText = ""
                                        
                                        // Immediately re-focus after clearing
                                        DispatchQueue.main.async {
                                            searchFieldFocused = true
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Clear search")
                                }
                            }
                            
                            if !viewModel.searchText.isEmpty {
                                Button {
                                    viewModel.searchText = ""
                                    searchFieldFocused = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Clear search")
                                .accessibilityLabel("Clear search")
                            }
                        }
                        
                        // Category filter buttons
                        if !viewModel.metadata.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.categoriesWithItems()) { category in
                                        CategoryFilterButton(
                                            category: category,
                                            isSelected: viewModel.selectedCategories.contains(category),
                                            itemCount: viewModel.categoryItemCounts()[category] ?? 0
                                        ) {
                                            toggleCategory(category)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .frame(minWidth: 250, idealWidth: 300)
            
            // Right side: Metadata display area
            VStack {
                if viewModel.isLoading {
                    LoadingView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.selectedFile == nil {
                    EmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.metadata.isEmpty && viewModel.searchText.isEmpty {
                    NoMetadataView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.metadata.isEmpty && !viewModel.searchText.isEmpty {
                    NoSearchResultsView(searchText: viewModel.searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Metadata content view
                    MetadataListView(viewModel: viewModel)
                }
            }
            .frame(minWidth: 450)
            .padding()
        }
        // Error handling
        .errorOverlay(
            viewModel.error,
            onDismiss: { viewModel.error = nil },
            alignment: .top,
            offset: CGPoint(x: 0, y: 40)
        )
        // Permission request handling
        .permissionRequestModal(
            isPresented: $viewModel.showingPermissionRequest,
            url: viewModel.permissionRequestURL,
            onRetry: {
                // Retry the last operation with the file if we have it
                if viewModel.selectedFile != nil {
                    Task {
                        await viewModel.refreshMetadata()
                    }
                } else {
                    Task {
                        _ = await viewModel.selectFile()
                    }
                }
            }
        )
        // Unsupported file type handling
        .unsupportedFileTypeModal(
            isPresented: $viewModel.showingUnsupportedFileType,
            url: viewModel.unsupportedFileURL,
            onTryAnyway: {
                if let url = viewModel.unsupportedFileURL {
                    Task {
                        await viewModel.tryProcessUnsupportedFile(url)
                    }
                }
            }
        )
        // Add copy confirmation popup
        .copyConfirmation(isShowing: $viewModel.showingCopyConfirmation, message: viewModel.copyConfirmationMessage)
        // Focus search field when data is loaded
        .onChange(of: viewModel.metadata) { newMetadata in
            if !newMetadata.isEmpty && viewModel.selectedFile != nil {
                // Focus the search field when metadata loads with a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    searchFieldFocused = true
                }
            }
        }
        // Handle keyboard shortcuts for search
        .keyboardShortcut("f", modifiers: .command) {
            searchFieldFocused = true
        }
        .task {
            // Focus search field when metadata is loaded with a short delay
            // to avoid conflict with other keyboard events
            if viewModel.selectedFile != nil && !viewModel.metadata.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    searchFieldFocused = true
                }
            }
        }
        // Accessibility labels
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FileMetaView Main Window")
    }
    
    /// Toggle a category's selection state
    /// - Parameter category: The category to toggle
    private func toggleCategory(_ category: MetadataCategory) {
        if viewModel.selectedCategories.contains(category) {
            // Don't allow deselecting if it's the only selected category
            if viewModel.selectedCategories.count > 1 {
                viewModel.selectedCategories.remove(category)
            }
        } else {
            viewModel.selectedCategories.insert(category)
        }
    }
}

// MARK: - Helper Views

/// View shown when no file is selected
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Welcome to FileMetaView")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Select a file using the button above or drop any file here to view its detailed metadata")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding()
    }
}

/// View shown when a file is selected but no metadata could be extracted
struct NoMetadataView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("No Metadata Found")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("No metadata could be extracted from this file. It may be an unsupported file type or the file might be corrupted.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .padding()
    }
}

/// View shown when search returns no results
struct NoSearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Search Results")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("No metadata items match the search term \"\(searchText)\".")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// View shown while metadata is loading
struct LoadingView: View {
    // ViewModel for showing progress
    @ObservedObject var viewModel: AppViewModel
    
    // Animation state for pulsing effect
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                if viewModel.isLargeFile {
                    // Show determinate progress for large files
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.loadingProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        
                        Text("\(Int(viewModel.loadingProgress * 100))% Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Enhanced indeterminate progress for normal files
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 4)
                            .opacity(0.3)
                            .foregroundColor(Color.accentColor)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.accentColor, lineWidth: 4)
                            .frame(width: 40, height: 40)
                            .rotationEffect(Angle(degrees: isPulsing ? 360 : 0))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isPulsing)
                            .onAppear {
                                isPulsing = true
                            }
                    }
                }
                
                Text("Loading Metadata...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .opacity(isPulsing ? 0.7 : 1.0)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                
                if viewModel.isLargeFile {
                    Text("Large file detected (\(viewModel.selectedFile?.formattedSize ?? ""))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Enhanced cancel button for all operations
                Button {
                    viewModel.cancelMetadataLoading()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.top, 8)
                .buttonStyle(.plain)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            }
            .padding()
        }
    }
}

/// Button for category filtering
struct CategoryFilterButton: View {
    let category: MetadataCategory
    let isSelected: Bool
    let itemCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption)
                
                Text(category.displayName)
                    .font(.caption)
                
                Text("(\(itemCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.color.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? category.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MetadataListView is now implemented in Views/Components/MetadataListView.swift

// MARK: - Keyboard Shortcut Extension

extension View {
    /// Add a keyboard shortcut with an action
    func keyboardShortcut(_ key: String, modifiers: EventModifiers, perform action: @escaping () -> Void) -> some View {
        self.background(
            Button("") {
                action()
            }
            .keyboardShortcut(KeyEquivalent(Character(key)), modifiers: modifiers)
            .opacity(0)
        )
    }
}
