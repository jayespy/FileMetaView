import SwiftUI
import Foundation

@main
struct FileMetaViewApp: App {
    // Initialize UserPreferences as a state object for the entire app
    @StateObject private var preferences = UserPreferences()
    
    // Use the new AppViewModel implemented in Step 7
    @StateObject private var appViewModel = AppViewModel(
        fileSelectionService: FileSystemSelectionService(),
        extractorFactory: MetadataExtractorFactory(),
        userPreferences: nil // Will be set in onAppear
    )
    
    // State for showing the preferences view
    @State private var isShowingPreferences = false
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: appViewModel)
                .frame(
                    minWidth: AppConfiguration.defaultWindowWidth * 0.75,
                    idealWidth: AppConfiguration.defaultWindowWidth, 
                    minHeight: AppConfiguration.defaultWindowHeight * 0.75,
                    idealHeight: AppConfiguration.defaultWindowHeight
                )
                .padding()
                .environmentObject(preferences)
                // Apply force active window behavior to main view
                .preferredColorScheme(preferences.themeOption.colorScheme)
                .accentColor(preferences.accentColorOption.color)
                .font(.system(size: 12 * preferences.textSizeOption.scaleFactor))
                .sheet(isPresented: $isShowingPreferences) {
                    PreferencesView(preferences: preferences)
                }
                .onAppear {
                    // Connect view model with preferences after they're fully initialized
                    if appViewModel.userPreferences == nil {
                        appViewModel.connectPreferences(preferences)
                    }
                    
                    // Simple app activation instead of complex window handling
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(TitleBarWindowStyle())
        // No toolbar style to maintain compatibility with macOS 12
        .commands {
            // File Menu customization
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    // Connected to AppViewModel
                    Task {
                        await appViewModel.selectFile()
                    }
                }
                // Using a standard menu shortcut
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Open Recent") {
                    // Will be implemented in Step 4
                    print("Open Recent menu clicked")
                }
                
                Divider()
                
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
            // Edit Menu customization
            CommandGroup(replacing: .pasteboard) {
                Button("Copy Metadata") {
                    // Copy all metadata to clipboard with feedback
                    guard let _ = appViewModel.selectedFile, !appViewModel.metadata.isEmpty else {
                        return
                    }
                    
                    let metadataText = appViewModel.metadata
                        .sorted(by: { $0.displayName < $1.displayName })
                        .map { "\($0.displayName): \($0.formattedValue)" }
                        .joined(separator: "\n")
                    
                    // Use the enhanced copy method with notification
                    appViewModel.copyToClipboard(
                        metadataText, 
                        message: "Copied \(appViewModel.metadata.count) metadata fields"
                    )
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(appViewModel.selectedFile == nil || appViewModel.metadata.isEmpty)
                
                Button("Copy Selected Value") {
                    // Will be implemented in Step 9
                    print("Copy Selected Value menu clicked")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(true) // Will be enabled when a value is selected
                
                Divider()
                
                Button("Select All") {
                    // Will be implemented in Step 9
                    print("Select All menu clicked")
                }
                .keyboardShortcut("a", modifiers: .command)
                .disabled(true) // Will be enabled when file is selected
            }
            
            // View Menu
            CommandMenu("View") {
                Button("Show Categories") {
                    // Will be implemented in Step 9
                    print("Show Categories menu clicked")
                    // Toggle categories view
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Show All Metadata") {
                    // Will be implemented in Step 5
                    print("Show All Metadata menu clicked")
                    // Toggle between showing all or limited metadata
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Divider()
                
                Button("Refresh Metadata") {
                    // Refresh the current file's metadata
                    guard appViewModel.selectedFile != nil else { return }
                    Task {
                        await appViewModel.refreshMetadata()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appViewModel.selectedFile == nil)
            }
            
            // Window Menu customization 
            CommandGroup(after: .windowSize) {
                Button("Preferences...") {
                    isShowingPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // Help Menu customization
            CommandGroup(replacing: .help) {
                Button("FileMetaView Help") {
                    // Basic help implementation
                    print("Help menu clicked")
                    // Will open help documentation in future versions
                }
                
                Link("Report an Issue", destination: URL(string: "https://github.com")!)
                
                Divider()
                
                Button("About FileMetaView") {
                    AppCommands.showAboutPanel()
                }
            }
            
            #if DEBUG
            // Debug menu - only available in debug builds
            CommandMenu("Debug") {
                if AppConfiguration.enableDebugMenu {
                    Button("Print Current State") {
                        print("Debug: Print Current State")
                        print("Selected File: \(String(describing: appViewModel.selectedFile?.name))")
                        print("Metadata Items: \(appViewModel.metadata.count)")
                        print("Selected Categories: \(appViewModel.selectedCategories.map { $0.displayName }.joined(separator: ", "))")
                        print("Is Loading: \(appViewModel.isLoading)")
                        print("Has Error: \(appViewModel.error != nil)")
                    }
                    
                    Button("Simulate File Selection") {
                        // Create a sample file at a known location for testing
                        let fileManager = FileManager.default
                        let tempDir = fileManager.temporaryDirectory
                        let fileURL = tempDir.appendingPathComponent("sample_test_file.txt")
                        
                        do {
                            // Create a sample text file
                            try "This is a sample test file for FileMetaView.".write(to: fileURL, atomically: true, encoding: .utf8)
                            
                            // Select the file
                            Task {
                                await appViewModel.handleFileDrop(url: fileURL)
                            }
                        } catch {
                            print("Debug: Failed to create sample file: \(error)")
                        }
                    }
                    
                    Divider()
                    
                    Button("Log System Information") {
                        print("Debug: System Information")
                        print("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
                        print("App Version: \(AppConfiguration.version)")
                        // Additional system info will be added in Step 7
                    }
                }
            }
            #endif
        }
    }
}
