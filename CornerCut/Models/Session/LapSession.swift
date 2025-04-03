import Foundation
import CoreLocation

enum SessionType: String, Codable, CaseIterable {
    case practice = "Practice"
    case qualifying = "Qualifying"
    case race = "Race"
    case testing = "Testing"
    
    var description: String {
        return self.rawValue
    }
}

enum WeatherCondition: String, Codable, CaseIterable {
    case sunny = "Sunny"
    case cloudy = "Cloudy"
    case rainy = "Rainy"
    case wet = "Wet"
    case dry = "Dry"
    case snow = "Snow"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .wet: return "drop.fill"
        case .dry: return "sun.min.fill"
        case .snow: return "snow"
        case .unknown: return "questionmark.circle"
        }
    }
}

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

struct LapSession: Identifiable, Codable {
    var id: UUID
    var trackId: UUID
    var trackName: String
    var sessionType: SessionType
    var startTime: Date
    var endTime: Date?
    var laps: [LapData]
    var notes: String
    var weather: WeatherCondition
    
    init(id: UUID = UUID(),
         trackId: UUID,
         trackName: String,
         sessionType: SessionType,
         startTime: Date = Date(),
         endTime: Date? = nil,
         laps: [LapData] = [],
         notes: String = "",
         weather: WeatherCondition = .unknown) {
        self.id = id
        self.trackId = trackId
        self.trackName = trackName
        self.sessionType = sessionType
        self.startTime = startTime
        self.endTime = endTime
        self.laps = laps
        self.notes = notes
        self.weather = weather
    }
    
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let interval = duration
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var bestLap: LapData? {
        return laps.filter { $0.isValid }.min(by: { $0.lapTime < $1.lapTime })
    }
    
    var formattedBestLap: String {
        guard let bestLap = bestLap else {
            return "No valid laps"
        }
        return bestLap.formattedLapTime
    }
    
    var lapCount: Int {
        return laps.filter { $0.isValid }.count
    }
    
    func getAverageLapTime() -> TimeInterval? {
        let validLaps = laps.filter { $0.isValid }
        guard !validLaps.isEmpty else { return nil }
        
        let totalTime = validLaps.reduce(0.0) { $0 + $1.lapTime }
        return totalTime / Double(validLaps.count)
    }
    
    func getLapDifferences() -> [TimeInterval] {
        guard let bestLap = bestLap?.lapTime else { return [] }
        
        return laps.filter { $0.isValid }.map { $0.lapTime - bestLap }
    }
    
    func getLapConsistency() -> Double? {
        let validLaps = laps.filter { $0.isValid }
        guard validLaps.count > 1 else { return nil }
        
        let times = validLaps.map { $0.lapTime }
        guard let average = getAverageLapTime() else { return nil }
        
        // Calculate standard deviation
        let sumOfSquaredDifferences = times.reduce(0.0) { $0 + pow($1 - average, 2) }
        let standardDeviation = sqrt(sumOfSquaredDifferences / Double(times.count))
        
        // Return coefficient of variation as a percentage (lower is more consistent)
        return (standardDeviation / average) * 100
    }
}
