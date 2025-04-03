import Foundation
import CoreLocation

struct TelemetryData: Identifiable, Codable {
    var id: UUID
    var sessionId: UUID
    var lapId: UUID?
    var timestamp: Date
    var location: GeoPoint
    var speed: Double          // m/s
    var heading: Double        // degrees
    var altitude: Double       // meters
    var gForceX: Double        // g's
    var gForceY: Double        // g's
    var gForceZ: Double        // g's
    var rotationRateX: Double  // deg/s
    var rotationRateY: Double  // deg/s
    var rotationRateZ: Double  // deg/s
    var engineRPM: Double?     // rpm
    var throttlePosition: Double? // percentage 0-100
    var brakePosition: Double?    // percentage 0-100
    var gear: Int?
    var engineTemp: Double?    // celsius
    var oilTemp: Double?       // celsius
    var oilPressure: Double?   // kPa
    var fuelLevel: Double?     // percentage 0-100
    var boost: Double?         // kPa
    
    init(id: UUID = UUID(),
         sessionId: UUID,
         lapId: UUID? = nil,
         timestamp: Date = Date(),
         location: GeoPoint,
         speed: Double,
         heading: Double,
         altitude: Double,
         gForceX: Double,
         gForceY: Double,
         gForceZ: Double,
         rotationRateX: Double,
         rotationRateY: Double,
         rotationRateZ: Double,
         engineRPM: Double? = nil,
         throttlePosition: Double? = nil,
         brakePosition: Double? = nil,
         gear: Int? = nil,
         engineTemp: Double? = nil,
         oilTemp: Double? = nil,
         oilPressure: Double? = nil,
         fuelLevel: Double? = nil,
         boost: Double? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.lapId = lapId
        self.timestamp = timestamp
        self.location = location
        self.speed = speed
        self.heading = heading
        self.altitude = altitude
        self.gForceX = gForceX
        self.gForceY = gForceY
        self.gForceZ = gForceZ
        self.rotationRateX = rotationRateX
        self.rotationRateY = rotationRateY
        self.rotationRateZ = rotationRateZ
        self.engineRPM = engineRPM
        self.throttlePosition = throttlePosition
        self.brakePosition = brakePosition
        self.gear = gear
        self.engineTemp = engineTemp
        self.oilTemp = oilTemp
        self.oilPressure = oilPressure
        self.fuelLevel = fuelLevel
        self.boost = boost
    }
    
    // Create from RaceBox data
    init(fromRaceBoxData data: RaceBoxData, sessionId: UUID, lapId: UUID? = nil) {
        self.id = UUID()
        self.sessionId = sessionId
        self.lapId = lapId
        self.timestamp = data.timestamp
        self.location = GeoPoint(latitude: data.latitude, longitude: data.longitude)
        self.speed = data.speed / 1000.0  // Convert mm/s to m/s
        self.heading = data.heading
        self.altitude = data.mslAltitude / 1000.0  // Convert mm to m
        self.gForceX = data.gForceX
        self.gForceY = data.gForceY
        self.gForceZ = data.gForceZ
        self.rotationRateX = data.rotationRateX
        self.rotationRateY = data.rotationRateY
        self.rotationRateZ = data.rotationRateZ
        
        // OBD data fields remain nil
        self.engineRPM = nil
        self.throttlePosition = nil
        self.brakePosition = nil
        self.gear = nil
        self.engineTemp = nil
        self.oilTemp = nil
        self.oilPressure = nil
        self.fuelLevel = nil
        self.boost = nil
    }
    
    // Create from CLLocation
    init(fromLocation location: CLLocation, sessionId: UUID, lapId: UUID? = nil) {
        self.id = UUID()
        self.sessionId = sessionId
        self.lapId = lapId
        self.timestamp = location.timestamp
        self.location = GeoPoint(coordinate: location.coordinate)
        self.speed = max(0, location.speed)  // Speed can be -1 if unavailable
        self.heading = location.course >= 0 ? location.course : 0  // Course can be -1 if unavailable
        self.altitude = location.altitude
        
        // Motion data is set to zero when using internal GPS
        self.gForceX = 0
        self.gForceY = 0
        self.gForceZ = 0
        self.rotationRateX = 0
        self.rotationRateY = 0
        self.rotationRateZ = 0
        
        // OBD data fields remain nil
        self.engineRPM = nil
        self.throttlePosition = nil
        self.brakePosition = nil
        self.gear = nil
        self.engineTemp = nil
        self.oilTemp = nil
        self.oilPressure = nil
        self.fuelLevel = nil
        self.boost = nil
    }
    
    // Get speed in different units
    func getSpeedKPH() -> Double {
        return speed * 3.6 // m/s to km/h
    }
    
    func getSpeedMPH() -> Double {
        return speed * 2.23694 // m/s to mph
    }
    
    // Calculate total G-force (vector magnitude)
    func getTotalGForce() -> Double {
        return sqrt(pow(gForceX, 2) + pow(gForceY, 2) + pow(gForceZ, 2))
    }
    
    // Calculate lateral G-force (cornering)
    func getLateralGForce() -> Double {
        return gForceY
    }
    
    // Calculate longitudinal G-force (acceleration/braking)
    func getLongitudinalGForce() -> Double {
        return gForceX
    }
    
    // Distance to another telemetry point
    func distance(to other: TelemetryData) -> Double {
        return location.distance(to: other.location)
    }
}
