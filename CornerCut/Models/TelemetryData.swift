import Foundation
import SwiftData

@Model
final class TelemetryData {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var speed: Double
    var rpm: Double
    var throttle: Double
    var brake: Double
    var latitude: Double
    var longitude: Double
    
    // Will add more datapoints once I figure out what the OBD reader can pull

    init(timestamp: Date,
         speed: Double,
         rpm: Double,
         throttle: Double,
         brake: Double,
         latitude: Double,
         longitude: Double) {
        
        self.id = UUID()
        self.timestamp = timestamp
        self.speed = speed
        self.rpm = rpm
        self.throttle = throttle
        self.brake = brake
        self.latitude = latitude
        self.longitude = longitude
    }
}
