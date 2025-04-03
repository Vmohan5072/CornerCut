import Foundation
import SwiftUI

struct AppConstants {
    // MARK: - App Information
    
    static let appName = "CornerCut"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - File Storage
    
    static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    static let sessionsDirectory = documentsDirectory.appendingPathComponent("Sessions")
    static let tracksDirectory = documentsDirectory.appendingPathComponent("Tracks")
    
    // MARK: - Timing
    
    static let minValidLapTime: TimeInterval = 10 // Minimum lap time to be considered valid (in seconds)
    static let maxValidLapTime: TimeInterval = 2000 // Maximum lap time to be considered valid (in seconds)
    
    // MARK: - Telemetry Thresholds
    
    static let maxSpeed: Double = 180 // Maximum speed on gauge displays (in mph or kph)
    static let maxRPM: Double = 8000 // Maximum RPM on gauge displays
    static let maxGForce: Double = 2.0 // Maximum G-force on G-force displays
    
    // MARK: - UI
    
    static let cornerRadius: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let standardPadding: CGFloat = 8
    
    // MARK: - Colors
    
    struct Colors {
        static let primaryAccent = Color.blue
        static let secondaryAccent = Color.orange
        static let success = Color.green
        static let warning = Color.yellow
        static let error = Color.red
        
        static let positiveDelta = Color.green
        static let negativeDelta = Color.red
        
        // Session type colors
        static let practice = Color.blue
        static let qualifying = Color.orange
        static let race = Color.red
        static let testing = Color.purple
        
        // Get color for session type
        static func forSessionType(_ type: SessionType) -> Color {
            switch type {
            case .practice: return practice
            case .qualifying: return qualifying
            case .race: return race
            case .testing: return testing
            }
        }
    }
    
    // MARK: - Bluetooth
    
    struct Bluetooth {
        static let scanTimeout: TimeInterval = 15 // Seconds to scan for devices
        static let connectionTimeout: TimeInterval = 10 // Seconds to wait for connection
        static let reconnectDelay: TimeInterval = 1 // Seconds to wait before reconnecting
    }
    
    // MARK: - Date Formatters
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Timing Formatters
    
    // Format a TimeInterval as mm:ss.xxx
    static func formatLapTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    // Format a TimeInterval as ss.xxx (for sector times)
    static func formatSectorTime(_ time: TimeInterval) -> String {
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d.%03d", seconds, milliseconds)
    }
    
    // Format a TimeInterval delta as +/-ss.xxx
    static func formatDelta(_ delta: TimeInterval) -> String {
        let sign = delta >= 0 ? "+" : "-"
        let absDelta = abs(delta)
        
        let seconds = Int(absDelta) % 60
        let milliseconds = Int((absDelta.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%@%02d.%03d", sign, seconds, milliseconds)
    }
}
