//
//  LocationManager.swift
//  RaceBoxLapTimer
//
//  Created for RaceBox Lap Timer App
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var speed: Double = 0 // in m/s
    @Published var course: Double = 0 // in degrees
    @Published var altitude: Double = 0 // in meters
    @Published var horizontalAccuracy: Double = 0 // in meters
    @Published var verticalAccuracy: Double = 0 // in meters
    
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 1 // meters
        locationManager.headingFilter = 1 // degrees
        locationManager.activityType = .automotiveNavigation
        
        // Request authorization
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Public Methods
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    // Convert speed to different units
    func speedInKPH() -> Double {
        return speed * 3.6 // m/s to km/h
    }
    
    func speedInMPH() -> Double {
        return speed * 2.23694 // m/s to mph
    }
    
    // Convert altitude to different units
    func altitudeInFeet() -> Double {
        return altitude * 3.28084 // meters to feet
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        } else {
            stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update properties
        self.location = location
        self.speed = max(0, location.speed) // Ensure speed is never negative
        self.course = location.course >= 0 ? location.course : 0 // Default to 0 if invalid
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
