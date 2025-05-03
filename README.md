# FileMetaView

A macOS application for viewing and exploring file metadata across various file types.

## Overview

FileMetaView is a native macOS application that allows users to select files and view comprehensive metadata information. Built with SwiftUI, it provides an intuitive interface for exploring file attributes, properties, and embedded metadata across different file formats.

## Features

- **Simple File Selection**: Select files via dialog or drag-and-drop
- **Comprehensive Metadata Display**: View up to 30 metadata fields per file
- **Specialized File Type Support**: Enhanced metadata extraction for:
  - Images (EXIF data)
  - Audio files (ID3 tags)
  - Documents
  - Video files
- **Organized Display**: Metadata grouped by logical categories
- **Search & Filter**: Quickly find specific metadata attributes
- **User Preferences**: Customize the display of metadata categories

## System Requirements

- macOS 12 (Monterey) or later
- Approximately 20MB of disk space
- Standard macOS permissions for file access
- No additional dependencies required

## Setup and Installation

### For Development

1. Ensure you have Xcode 14 or later installed with Swift 5.7+ support
2. Clone or download this repository
3. Open the project in Xcode by double-clicking the `Package.swift` file
4. Build the project using ⌘+B or select Product > Build
5. Run the application using ⌘+R or select Product > Run

### For Usage

1. Download the FileMetaView.app file from the repository
2. Move the application to your Applications folder
3. Right-click the app and select "Open" for the first launch (to bypass Gatekeeper)
4. Grant file access permissions when prompted
5. Launch the application normally from Launchpad or Applications folder for subsequent uses

#### Note on Security

When first launching FileMetaView, macOS may display a security warning because the application is not notarized. This is expected for personal-use applications. Use the right-click method described above to bypass this warning.

## Usage

1. Launch FileMetaView
2. Click "Select File" or drag and drop a file onto the application window
3. View the file's metadata organized by categories:
   - Basic (name, size, dates)
   - Permissions (access rights)
   - Extended (additional file attributes)
   - Media (specialized metadata for images, audio, video)
   - Custom (application-specific metadata)
4. Use the search field (⌘+F) to filter metadata items by name or value
5. Access additional options through the application menu, including:
   - Preferences for customizing metadata display
   - Clearing the current selection
   - Refreshing metadata for the current file

### Keyboard Shortcuts

- **⌘+O**: Open file selection dialog
- **⌘+F**: Focus search field
- **⌘+R**: Refresh metadata for current file
- **⌘+,**: Open preferences
- **Esc**: Clear search or selection

### Limitations

- Maximum of 30 metadata fields displayed per file
- Some specialized metadata may not be accessible for files with restricted permissions
- Performance may vary with extremely large files (>1GB)

## Architecture

FileMetaView follows the Model-View-ViewModel (MVVM) architecture pattern:

- **Models**: Core data structures for file references and metadata
- **Views**: SwiftUI interface components
- **ViewModels**: Connect UI with business logic, manage state
- **Services**: Handle file selection and metadata extraction
- **Utilities**: Support functions for common operations

## File Organization

- **Models/**: Data structures (`FileReference`, `MetadataItem`, etc.)
- **Views/**: SwiftUI interface components
- **ViewModels/**: State management and business logic
- **Services/**: File operations and metadata extraction
- **Utilities/**: Helper functions and extensions
- **Resources/**: Assets and configuration files

## Privacy & Security

FileMetaView:
- Processes files locally and does not transfer any data over the network
- Requires file read permissions only for selected files
- Does not modify any files or metadata
- Does not store file contents, only metadata while the app is running
- Does not collect any usage data or analytics

## License

This project is for personal use only and is not licensed for commercial distribution.

## Acknowledgments

FileMetaView uses native macOS frameworks including:
- SwiftUI for the user interface
- URLResourceValues for basic file attributes
- MDItem APIs for extended metadata extraction
- AppKit for native macOS integration
- Swift Package Manager for dependency management