import Foundation
import SwiftData
import CoreLocation

@Model
final class TelemetryData {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var speed: Double       // m/s
    var rpm: Double
    var throttle: Double    // 0-100%
    var latitude: Double
    var longitude: Double
    
    // Add to better handle missing data
    var hasValidLocation: Bool
    var hasValidRPM: Bool
    var hasValidThrottle: Bool

    init(timestamp: Date,
         speed: Double,
         rpm: Double,
         throttle: Double,
         latitude: Double,
         longitude: Double) {

        self.id = UUID()
        self.timestamp = timestamp
        self.speed = speed
        self.rpm = rpm
        self.throttle = throttle
        self.latitude = latitude
        self.longitude = longitude
        
        // Validate data
        self.hasValidLocation = latitude != 0 && longitude != 0
        self.hasValidRPM = rpm > 0
        self.hasValidThrottle = throttle >= 0 && throttle <= 100
    }
    
    // Convenience initializer for when some data is missing
    convenience init(timestamp: Date, speed: Double, location: CLLocation?) {
        self.init(
            timestamp: timestamp,
            speed: speed,
            rpm: 0,
            throttle: 0,
            latitude: location?.coordinate.latitude ?? 0,
            longitude: location?.coordinate.longitude ?? 0
        )
    }
    
    // Get CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Speed in mph
    var speedMPH: Double {
        return speed * 2.23694
    }
    
    // Speed in kph
    var speedKPH: Double {
        return speed * 3.6
    }
}
