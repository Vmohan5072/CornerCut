//
//  SettingsManager.swift
//  RaceBoxLapTimer
//
//  Created for RaceBox Lap Timer App
//

import Foundation

class SettingsManager {
    // MARK: - Singleton
    
    static let shared = SettingsManager()
    
    // MARK: - Settings Keys
    
    private enum Keys {
        static let gpsSource = "gpsSource"
        static let isOBDEnabled = "isOBDEnabled"
        static let unitSystem = "unitSystem"
        static let darkMode = "darkMode"
        static let sampleRate = "sampleRate"
    }
    
    // MARK: - Properties
    
    var gpsSource: GPSSource {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.gpsSource),
               let source = GPSSource(rawValue: rawValue) {
                return source
            }
            return .internal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.gpsSource)
        }
    }
    
    var isOBDEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.isOBDEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isOBDEnabled)
        }
    }
    
    var unitSystem: UnitSystem {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Keys.unitSystem),
               let system = UnitSystem(rawValue: rawValue) {
                return system
            }
            return .imperial
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.unitSystem)
        }
    }
    
    var isDarkModeEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.darkMode)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.darkMode)
        }
    }
    
    var sampleRate: SampleRate {
        get {
            if let rawValue = UserDefaults.standard.integer(forKey: Keys.sampleRate),
               let rate = SampleRate(rawValue: Int(rawValue)) {
                return rate
            }
            return .hz25
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.sampleRate)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDefaults()
    }
    
    // MARK: - Private Methods
    
    private func setupDefaults() {
        if UserDefaults.standard.object(forKey: Keys.gpsSource) == nil {
            UserDefaults.standard.set(GPSSource.internal.rawValue, forKey: Keys.gpsSource)
        }
        
        if UserDefaults.standard.object(forKey: Keys.isOBDEnabled) == nil {
            UserDefaults.standard.set(false, forKey: Keys.isOBDEnabled)
        }
        
        if UserDefaults.standard.object(forKey: Keys.unitSystem) == nil {
            UserDefaults.standard.set(UnitSystem.imperial.rawValue, forKey: Keys.unitSystem)
        }
        
        if UserDefaults.standard.object(forKey: Keys.darkMode) == nil {
            UserDefaults.standard.set(false, forKey: Keys.darkMode)
        }
        
        if UserDefaults.standard.object(forKey: Keys.sampleRate) == nil {
            UserDefaults.standard.set(SampleRate.hz25.rawValue, forKey: Keys.sampleRate)
        }
    }
}

enum UnitSystem: String {
    case imperial = "imperial"
    case metric = "metric"
}

enum SampleRate: Int {
    case hz1 = 1
    case hz5 = 5
    case hz10 = 10
    case hz20 = 20
    case hz25 = 25
    
    var description: String {
        return "\(rawValue) Hz"
    }
}
