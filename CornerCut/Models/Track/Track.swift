//
//  Track.swift
//  RaceBoxLapTimer
//

import Foundation
import CoreLocation
import MapKit

struct Track: Identifiable, Codable {
    var id: UUID
    var name: String
    var type: TrackType
    var startFinishLine: StartFinishLine
    var sector1Point: GeoPoint?
    var sector2Point: GeoPoint?
    var location: String
    var trackLength: Double? // In meters
    var createdDate: Date
    var lastUsedDate: Date?
    var bestLapTime: TimeInterval?
    
    init(id: UUID = UUID(),
         name: String,
         type: TrackType,
         startFinishLine: StartFinishLine,
         sector1Point: GeoPoint? = nil,
         sector2Point: GeoPoint? = nil,
         location: String = "",
         trackLength: Double? = nil,
         createdDate: Date = Date(),
         lastUsedDate: Date? = nil,
         bestLapTime: TimeInterval? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.startFinishLine = startFinishLine
        self.sector1Point = sector1Point
        self.sector2Point = sector2Point
        self.location = location
        self.trackLength = trackLength
        self.createdDate = createdDate
        self.lastUsedDate = lastUsedDate
        self.bestLapTime = bestLapTime
    }
    
    // Get the track's region for map display
    func getRegion() -> MKCoordinateRegion {
        let startCoordinate = startFinishLine.point.coordinate
        
        // Default span values
        var latDelta: CLLocationDegrees = 0.01
        var lonDelta: CLLocationDegrees = 0.01
        
        // If we have both start and end points for a point-to-point track,
        // calculate the span to include both
        if type == .pointToPoint, let endPoint = startFinishLine.endPoint {
            let endCoordinate = endPoint.coordinate
            
            // Get min/max coordinates
            let minLat = min(startCoordinate.latitude, endCoordinate.latitude)
            let maxLat = max(startCoordinate.latitude, endCoordinate.latitude)
            let minLon = min(startCoordinate.longitude, endCoordinate.longitude)
            let maxLon = max(startCoordinate.longitude, endCoordinate.longitude)
            
            // Calculate span with padding
            latDelta = (maxLat - minLat) * 1.5
            lonDelta = (maxLon - minLon) * 1.5
            
            // Ensure minimum zoom level
            latDelta = max(latDelta, 0.01)
            lonDelta = max(lonDelta, 0.01)
            
            // Center point
            let centerLat = (maxLat + minLat) / 2
            let centerLon = (maxLon + minLon) / 2
            
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        }
        
        // For circuit or simple point-to-point with just start
        return MKCoordinateRegion(
            center: startCoordinate,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
    
    // Format best lap time as string
    var formattedBestLapTime: String {
        guard let bestLapTime = bestLapTime else {
            return "No time set"
        }
        
        let minutes = Int(bestLapTime) / 60
        let seconds = Int(bestLapTime) % 60
        let milliseconds = Int((bestLapTime.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

enum TrackType: String, Codable, CaseIterable {
    case circuit = "Circuit"
    case pointToPoint = "Point to Point"
    
    var description: String {
        switch self {
        case .circuit:
            return "Circuit (single start/finish line)"
        case .pointToPoint:
            return "Point to Point (separate start and end)"
        }
    }
}

struct StartFinishLine: Codable {
    var point: GeoPoint
    var endPoint: GeoPoint?
    var width: Double // in meters
    
    init(point: GeoPoint, endPoint: GeoPoint? = nil, width: Double = 10.0) {
        self.point = point
        self.endPoint = endPoint
        self.width = width
    }
}

struct GeoPoint: Codable {
    var latitude: Double
    var longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    // Calculate distance to another point in meters
    func distance(to point: GeoPoint) -> Double {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: point.latitude, longitude: point.longitude)
        return from.distance(from: to)
    }
}
