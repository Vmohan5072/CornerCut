import Foundation
import CoreLocation

struct LapData: Identifiable, Codable {
    var id: UUID
    var lapNumber: Int
    var lapTime: TimeInterval
    var sector1Time: TimeInterval?
    var sector2Time: TimeInterval?
    var sector3Time: TimeInterval?
    var maxSpeed: Double?  // in m/s
    var averageSpeed: Double?  // in m/s
    var telemetryDataId: UUID?
    var isValid: Bool
    var invalidReason: String?
    
    init(id: UUID = UUID(),
         lapNumber: Int,
         lapTime: TimeInterval,
         sector1Time: TimeInterval? = nil,
         sector2Time: TimeInterval? = nil,
         sector3Time: TimeInterval? = nil,
         maxSpeed: Double? = nil,
         averageSpeed: Double? = nil,
         telemetryDataId: UUID? = nil,
         isValid: Bool = true,
         invalidReason: String? = nil) {
        self.id = id
        self.lapNumber = lapNumber
        self.lapTime = lapTime
        self.sector1Time = sector1Time
        self.sector2Time = sector2Time
        self.sector3Time = sector3Time
        self.maxSpeed = maxSpeed
        self.averageSpeed = averageSpeed
        self.telemetryDataId = telemetryDataId
        self.isValid = isValid
        self.invalidReason = invalidReason
    }
    
    var formattedLapTime: String {
        let minutes = Int(lapTime) / 60
        let seconds = Int(lapTime) % 60
        let milliseconds = Int((lapTime.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    func formatSectorTime(_ time: TimeInterval?) -> String {
        guard let time = time else { return "--:--.---" }
        
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d.%03d", seconds, milliseconds)
    }
    
    var formattedSector1Time: String {
        return formatSectorTime(sector1Time)
    }
    
    var formattedSector2Time: String {
        return formatSectorTime(sector2Time)
    }
    
    var formattedSector3Time: String {
        return formatSectorTime(sector3Time)
    }
    
    var maxSpeedKPH: Double? {
        guard let maxSpeed = maxSpeed else { return nil }
        return maxSpeed * 3.6
    }
    
    var maxSpeedMPH: Double? {
        guard let maxSpeed = maxSpeed else { return nil }
        return maxSpeed * 2.23694
    }
    
    var averageSpeedKPH: Double? {
        guard let averageSpeed = averageSpeed else { return nil }
        return averageSpeed * 3.6
    }
    
    var averageSpeedMPH: Double? {
        guard let averageSpeed = averageSpeed else { return nil }
        return averageSpeed * 2.23694
    }
}
