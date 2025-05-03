import SwiftUI
import UniformTypeIdentifiers

/// View component that handles file selection via button and drag-and-drop
struct FileSelectionView: View {
    /// The view model for the application
    @ObservedObject var viewModel: AppViewModel
    
    /// State for drag-and-drop highlighting
    @State private var isDropTargetActive: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("FileMetaView")
                .font(.largeTitle)
                .padding(.top)
                .accessibilityAddTraits(.isHeader)
            
            Text("Select a file to view its metadata")
                .font(.title2)
                .foregroundColor(.secondary)
                .accessibilityLabel("Instructions: Select a file to view its metadata")
            
            Button {
                Task {
                    await viewModel.selectFile()
                }
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .imageScale(.large)
                    Text("Select File")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding()
            .keyboardShortcut("o", modifiers: .command)
            .accessibilityLabel("Select a file from your computer")
            .help("Open file browser to select a file (⌘O)")
            
            // Drag and drop area
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isDropTargetActive ? Color.accentColor : Color.gray.opacity(0.5),
                        style: StrokeStyle(
                            lineWidth: isDropTargetActive ? 3 : 2,
                            dash: isDropTargetActive ? [] : [5]
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDropTargetActive ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                    .frame(height: 120)
                
                VStack {
                    Image(systemName: isDropTargetActive ? "doc.badge.arrow.down" : "arrow.down.doc")
                        .font(.largeTitle)
                        .foregroundColor(isDropTargetActive ? .accentColor : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: isDropTargetActive)
                    
                    Text(isDropTargetActive ? "Drop to view metadata" : "Drag files here")
                        .foregroundColor(isDropTargetActive ? .accentColor : .secondary)
                        .font(isDropTargetActive ? .headline : .body)
                        .animation(.easeInOut(duration: 0.2), value: isDropTargetActive)
                }
            }
            .padding()
            .contentShape(Rectangle())
            .accessibilityLabel(isDropTargetActive ? "Drop zone active - release to analyze file" : "Drag and drop area - drag files here")
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileDropDelegate(
                    fileService: viewModel.fileSelectionService,
                    onFileSelected: { fileReference in
                        Task {
                            await viewModel.handleFileDrop(url: fileReference.url)
                        }
                        // Reset drop target state
                        DispatchQueue.main.async {
                            self.isDropTargetActive = false
                        }
                    },
                    onError: { fileError in
                        // Handle errors via the view model for consistent logging
                        DispatchQueue.main.async {
                            viewModel.error = fileError
                            // Reset drop target state
                            self.isDropTargetActive = false
                        }
                    },
                    onDropEnter: {
                        DispatchQueue.main.async {
                            self.isDropTargetActive = true
                            viewModel.isDropTargetActive = true
                        }
                    },
                    onDropExit: {
                        DispatchQueue.main.async {
                            self.isDropTargetActive = false
                            viewModel.isDropTargetActive = false
                        }
                    }
                )
            )
            
            if let selectedFile = viewModel.selectedFile {
                HStack {
                    if let icon = selectedFile.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(selectedFile.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(selectedFile.typeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            viewModel.clearSelection()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear current selection")
                    .accessibilityLabel("Clear selected file")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
                .padding(.horizontal)
            }
            
            // Additional file info if available
            if let file = viewModel.selectedFile {
                VStack(alignment: .leading, spacing: 4) {
                    Divider().padding(.vertical, 8)
                    
                    HStack {
                        Text("Size:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    if let creationDate = file.creationDate {
                        HStack {
                            Text("Created:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formatDate(creationDate))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let modificationDate = file.modificationDate {
                        HStack {
                            Text("Modified:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formatDate(modificationDate))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    /// Format a date for display
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Drop Target Extension

/// Extension to provide drop target modifier for views
extension View {
    /// Apply a drop target style to this view
    /// - Parameters:
    ///   - isActive: Binding to the active state
    ///   - dragColor: Color to use when active
    /// - Returns: Modified view
    func dropTarget(isActive: Binding<Bool>, dragColor: Color = .accentColor) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isActive.wrappedValue ? dragColor : Color.clear,
                    style: StrokeStyle(
                        lineWidth: 3,
                        dash: []
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive.wrappedValue ? dragColor.opacity(0.1) : Color.clear)
                )
        )
    }
}