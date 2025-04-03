import Foundation
import CoreLocation

// MARK: - RaceBox Device Types
enum RaceBoxDeviceType: String {
    case mini = "RaceBox Mini"
    case miniS = "RaceBox Mini S"
    case micro = "RaceBox Micro"
    case unknown = "Unknown"
    
    static func fromModelString(_ model: String) -> RaceBoxDeviceType {
        switch model {
        case "RaceBox Mini": return .mini
        case "RaceBox Mini S": return .miniS
        case "RaceBox Micro": return .micro
        default: return .unknown
        }
    }
}

// MARK: - RaceBox Data Model
struct RaceBoxData {
    // GNSS Time/Date
    var iTOW: UInt32 = 0  // Time of week in milliseconds
    var year: UInt16 = 0
    var month: UInt8 = 0
    var day: UInt8 = 0
    var hour: UInt8 = 0
    var minute: UInt8 = 0
    var second: UInt8 = 0
    var validityFlags: UInt8 = 0
    var timeAccuracy: UInt32 = 0
    var nanoseconds: Int32 = 0
    
    // Fix Status
    var fixStatus: UInt8 = 0 // 0: no fix, 2: 2D fix, 3: 3D fix
    var fixStatusFlags: UInt8 = 0
    var dateTimeFlags: UInt8 = 0
    var numSVs: UInt8 = 0 // Number of satellites
    
    // Location
    var longitude: Double = 0 // Factor of 10^7
    var latitude: Double = 0  // Factor of 10^7
    var wgsAltitude: Double = 0 // Millimeters
    var mslAltitude: Double = 0 // Millimeters
    var horizontalAccuracy: Double = 0 // Millimeters
    var verticalAccuracy: Double = 0 // Millimeters
    
    // Movement
    var speed: Double = 0 // Millimeters per second
    var heading: Double = 0 // Degrees with factor of 10^5
    var speedAccuracy: Double = 0 // Millimeters per second
    var headingAccuracy: Double = 0 // Degrees with factor of 10^5
    var pdop: Double = 0 // Factor of 100
    
    // Flags
    var latLonFlags: UInt8 = 0
    var batteryStatus: UInt8 = 0 // Charge status and level for Mini/Mini S, voltage for Micro
    
    // IMU data
    var gForceX: Double = 0 // Milli-g
    var gForceY: Double = 0 // Milli-g
    var gForceZ: Double = 0 // Milli-g
    var rotationRateX: Double = 0 // Centi-degrees per second
    var rotationRateY: Double = 0 // Centi-degrees per second
    var rotationRateZ: Double = 0 // Centi-degrees per second
    
    // Computed Properties
    var timestamp: Date {
        var components = DateComponents()
        components.year = Int(year)
        components.month = Int(month)
        components.day = Int(day)
        components.hour = Int(hour)
        components.minute = Int(minute)
        components.second = Int(second)
        components.nanosecond = Int(nanoseconds)
        
        return Calendar.current.date(from: components) ?? Date()
    }
    
    var speedKPH: Double {
        return speed * 0.0036 // Convert mm/s to km/h
    }
    
    var speedMPH: Double {
        return speedKPH * 0.621371 // Convert km/h to mph
    }
    
    var altitudeMeters: Double {
        return mslAltitude / 1000.0 // Convert mm to m
    }
    
    var horizontalAccuracyMeters: Double {
        return horizontalAccuracy / 1000.0 // Convert mm to m
    }
    
    var hasValidFix: Bool {
        return (fixStatusFlags & 0x01) != 0 && fixStatus == 3
    }
    
    var batteryPercentage: Int {
        if batteryStatus & 0x80 != 0 {
            // For Mini/Mini S: MSB is charging status, rest is battery level
            return Int(batteryStatus & 0x7F)
        } else {
            // For Micro: This is voltage, not percentage
            return -1
        }
    }
    
    var isCharging: Bool {
        return batteryStatus & 0x80 != 0
    }
    
    var microvoltage: Double {
        if batteryPercentage == -1 {
            // For Micro: Value is voltage * 10
            return Double(batteryStatus) / 10.0
        }
        return 0
    }
}

// MARK: - RaceBox Device Info
struct RaceBoxDeviceInfo {
    var model: String = ""
    var serialNumber: String = ""
    var firmwareRevision: String = ""
    var hardwareRevision: String = ""
    var manufacturer: String = ""
    
    var deviceType: RaceBoxDeviceType {
        return RaceBoxDeviceType.fromModelString(model)
    }
    
    var firmwareVersion: (major: Int, minor: Int) {
        let components = firmwareRevision.split(separator: ".")
        let major = Int(components.first ?? "0") ?? 0
        let minor = components.count > 1 ? (Int(components[1]) ?? 0) : 0
        return (major, minor)
    }
    
    var supportsNMEA: Bool {
        return firmwareVersion.major >= 3 && firmwareVersion.minor >= 3
    }
    
    var supportsPlatformConfig: Bool {
        return firmwareVersion.major >= 3 && firmwareVersion.minor >= 3
    }
    
    var supportsRecording: Bool {
        return deviceType == .miniS || deviceType == .micro
    }
}

// MARK: - RaceBox Platform Configuration
struct RaceBoxPlatformConfig {
    enum DynamicPlatformModel: UInt8 {
        case automotive = 4
        case sea = 5
        case airLowDynamics = 6
        case airHighDynamics = 8
        
        var description: String {
            switch self {
            case .automotive: return "Automotive (Ground)"
            case .sea: return "Maritime"
            case .airLowDynamics: return "Airborne <1g"
            case .airHighDynamics: return "Airborne <4g"
            }
        }
    }
    
    var platformModel: DynamicPlatformModel = .automotive
    var enable3DSpeed: Bool = false
    var minHorizontalAccuracy: UInt8 = 3 // in meters
}

// MARK: - RaceBox Recording Status
struct RaceBoxRecordingStatus {
    var isRecording: Bool = false
    var memoryLevel: UInt8 = 0  // 0-100%
    var isMemorySecurityEnabled: Bool = false
    var isMemoryUnlocked: Bool = false
    var storedDataMessages: UInt32 = 0
    var deviceMemorySize: UInt32 = 0
    
    var memoryPercentage: Double {
        return Double(storedDataMessages) / Double(deviceMemorySize) * 100.0
    }
}

// MARK: - RaceBox BLE Protocol Constants
enum RaceBoxProtocol {
    // Service UUIDs
    static let uartServiceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartRXCharUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartTXCharUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    static let nmeaServiceUUID = "00001101-0000-1000-8000-00805F9B34FB"
    static let nmeaRXCharUUID = "00001102-0000-1000-8000-00805F9B34FB"
    static let nmeaTXCharUUID = "00001103-0000-1000-8000-00805F9B34FB"
    
    static let deviceInfoServiceUUID = "0000180A-0000-1000-8000-00805F9B34FB"
    static let modelCharUUID = "00002A24-0000-1000-8000-00805F9B34FB"
    static let serialNumberCharUUID = "00002A25-0000-1000-8000-00805F9B34FB"
    static let firmwareRevisionCharUUID = "00002A26-0000-1000-8000-00805F9B34FB"
    static let hardwareRevisionCharUUID = "00002A27-0000-1000-8000-00805F9B34FB"
    static let manufacturerCharUUID = "00002A29-0000-1000-8000-00805F9B34FB"
    
    // Message classes and IDs
    enum MessageClass: UInt8 {
        case ubx = 0xFF // RaceBox custom class
    }
    
    enum MessageID: UInt8 {
        case dataMessage = 0x01
        case ack = 0x02
        case nack = 0x03
        case historyDataMessage = 0x21
        case recordingStatus = 0x22
        case dataDownload = 0x23
        case dataErase = 0x24
        case recordingConfig = 0x25
        case recordingStateChange = 0x26
        case platformConfig = 0x27
        case memoryUnlock = 0x30
    }
    
    // Packet structure constants
    static let packetStartBytes: [UInt8] = [0xB5, 0x62]
}
