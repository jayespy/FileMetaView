import SwiftUI

extension Color {
    /// The app's accent color
    static var appAccent: Color {
        Color("AccentColor")
    }
    
    /// Background color that adapts to light/dark mode
    static var appBackground: Color {
        Color("BackgroundColor")
    }
    
    /// Primary text color that adapts to light/dark mode
    static var appText: Color {
        Color("PrimaryTextColor")
    }
    
    /// Secondary text color that adapts to light/dark mode
    static var appSecondaryText: Color {
        Color("SecondaryTextColor")
    }
    
    /// Creates a color that adapts based on the current theme
    /// - Parameters:
    ///   - light: The color to use in light mode
    ///   - dark: The color to use in dark mode
    static func adaptable(light: Color, dark: Color) -> Color {
        #if os(macOS)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        // Fallback implementation, though our app is macOS-only
        return light
        #endif
    }
    
    /// Initialize a Color from a hexadecimal string
    /// - Parameter hex: Hex string in format "#RRGGBB" or "#RRGGBBAA"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Extensions for standard SwiftUI views to use our custom colors
extension View {
    /// Apply the app's standard background style
    func appBackgroundStyle() -> some View {
        self.background(Color.appBackground)
    }
    
    /// Apply the app's standard text style
    func appTextStyle() -> some View {
        self.foregroundColor(Color.appText)
    }
    
    /// Apply the app's secondary text style
    func appSecondaryTextStyle() -> some View {
        self.foregroundColor(Color.appSecondaryText)
    }
}

// For standard styling of elements
extension Text {
    /// Apply the app's primary text style
    func primaryStyle() -> some View {
        self.foregroundColor(.appText)
    }
    
    /// Apply the app's secondary text style
    func secondaryStyle() -> some View {
        self.foregroundColor(.appSecondaryText)
    }
    
    /// Apply the app's accent style
    func accentStyle() -> some View {
        self.foregroundColor(.appAccent)
    }
}