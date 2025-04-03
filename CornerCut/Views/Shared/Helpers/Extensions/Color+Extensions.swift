import SwiftUI

extension Color {
    // Initialize with hex string like "#FF0000"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Convert color to hex string
    func toHex() -> String {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0

        let hexString = String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r * 255)),
            lroundf(Float(g * 255)),
            lroundf(Float(b * 255))
        )
        return hexString
    }
    
    // App-specific theme colors
    static let appPrimary = Color("PrimaryColor", bundle: nil)
    static let appSecondary = Color("SecondaryColor", bundle: nil)
    static let appAccent = Color("AccentColor", bundle: nil)
    static let appBackground = Color("BackgroundColor", bundle: nil)
    
    // Custom semantic colors for app-specific use cases
    static let positiveValue = Color.green
    static let negativeValue = Color.red
    static let warningValue = Color.yellow
    static let neutralValue = Color.gray
    
    // Timing-specific colors
    static func forDeltaTime(_ delta: TimeInterval) -> Color {
        if delta < 0 {
            return positiveValue // Faster/better time
        } else if delta == 0 {
            return neutralValue // Same time
        } else {
            return negativeValue // Slower/worse time
        }
    }
    
    // Return a color for session type
    static func forSessionType(_ type: SessionType) -> Color {
        switch type {
        case .practice:
            return .blue
        case .qualifying:
            return .orange
        case .race:
            return .red
        case .testing:
            return .purple
        }
    }
    
    // Get a color for a percentage value (0-100)
    // Low is red, middle is yellow, high is green
    static func forPercentage(_ value: Double) -> Color {
        let normalized = min(max(value, 0), 100) / 100
        
        if normalized < 0.5 {
            // Interpolate between red and yellow
            return Color(
                red: 1.0,
                green: normalized * 2,
                blue: 0.0
            )
        } else {
            // Interpolate between yellow and green
            return Color(
                red: 1.0 - (normalized - 0.5) * 2,
                green: 1.0,
                blue: 0.0
            )
        }
    }
    
    // Get a color for a value between min and max
    static func forValue(_ value: Double, min: Double, max: Double, reversed: Bool = false) -> Color {
        let range = max - min
        guard range > 0 else { return .gray }
        
        let normalizedValue = (value - min) / range
        let percentage = reversed ? 100 - (normalizedValue * 100) : normalizedValue * 100
        
        return forPercentage(percentage)
    }
}
