//
//  SessionViewModel.swift
//  CornerCut
//

import Foundation
import Combine
import CoreLocation
import SwiftUI

class SessionViewModel: ObservableObject {
    // MARK: - Published Session Data
    
    @Published var trackName: String = ""
    @Published var sessionType: SessionType = .practice
    @Published var isSessionActive: Bool = false
    @Published var currentLap: Int = 0
    @Published var formattedCurrentLapTime: String = "00:00.000"
    @Published var formattedLastLapTime: String = "--:--.---"
    @Published var formattedBestLapTime: String = "--:--.---"
    @Published var formattedDeltaTime: String = "+00.000"
    @Published var isDeltaPositive: Bool = true
    
    // MARK: - Published Sector Data
    
    @Published var hasSectors: Bool = false
    @Published var sector1Completed: Bool = false
    @Published var sector2Completed: Bool = false
    @Published var sector3Completed: Bool = false
    @Published var formattedSector1Time: String = "--:--"
    @Published var formattedSector2Time: String = "--:--"
    @Published var formattedSector3Time: String = "--:--"
    @Published var isSector1Fastest: Bool = false
    @Published var isSector2Fastest: Bool = false
    @Published var isSector3Fastest: Bool = false
    @Published var sector1Color: Color = .white
    @Published var sector2Color: Color = .white
    @Published var sector3Color: Color = .white
    
    // MARK: - Published Telemetry Data
    
    @Published var speed: Double = 0
    @Published var displaySpeed: Double = 0
    @Published var speedUnit: String = "MPH"
    @Published var rpm: Double = 0
    @Published var throttlePosition: Double = 0
    @Published var brakePosition: Double = 0
    @Published var lateralG: Double = 0
    @Published var longitudinalG: Double = 0
    @Published var currentGear: String = "N"
    
    // MARK: - Published Status Data
    
    @Published var hasGPSSignal: Bool = false
    @Published var hasOBDConnection: Bool = false
    @Published var isOBDEnabled: Bool = false
    
    // MARK: - Private Properties
    
    private var track: Track?
    private var lapStartTime: Date?
    private var lastLapTime: TimeInterval?
    private var bestLapTime: TimeInterval?
    private var currentLapTimer: Timer?
    private var lastUpdateTime: Date?
    private var currentLapDelta: TimeInterval = 0
    private var bestSector1Time: TimeInterval?
    private var bestSector2Time: TimeInterval?
    private var bestSector3Time: TimeInterval?
    private var sector1Time: TimeInterval?
    private var sector2Time: TimeInterval?
    private var sector3Time: TimeInterval?
    private var lastSpeed: Double?
    
    private var sessionManager = SessionManager.shared
    private var bluetoothManager: BluetoothManager?
    private var locationManager: LocationManager?
    private var settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Constants
    let maxSpeed: Double = 180 // Maximum on the gauge
    let maxRPM: Double = 8000  // Maximum on the gauge
    
    // MARK: - Initialization
    
    init(bluetoothManager: BluetoothManager? = nil, locationManager: LocationManager? = nil) {
        self.bluetoothManager = bluetoothManager
        self.locationManager = locationManager
        
        setup()
    }
    
    // MARK: - Public Methods
    
    func startSession(track: Track, sessionType: SessionType) {
        self.track = track
        self.trackName = track.name
        self.sessionType = sessionType
        
        // Reset all values
        resetSessionValues()
        
        // Start location updates if using internal GPS
        if settingsManager.gpsSource == .internal {
            locationManager?.startUpdatingLocation()
        }
        
        // Subscribe to telemetry updates
        setupTelemetrySubscriptions()
        
        // Start the session in the session manager
        sessionManager.startSession(track: track, sessionType: sessionType)
        
        // Start the lap timer
        startLapTimer()
        
        isSessionActive = true
    }
    
    func endSession() {
        // Stop the lap timer
        stopLapTimer()
        
        // End the session in the session manager
        sessionManager.endSession()
        
        // Stop location updates if using internal GPS
        if settingsManager.gpsSource == .internal {
            locationManager?.stopUpdatingLocation()
        }
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        isSessionActive = false
    }
    
    // MARK: - Private Methods
    
    private func setup() {
        // Setup unit preferences
        updateUnitPreferences()
        
        // OBD availability
        isOBDEnabled = settingsManager.isOBDEnabled
        
        // Setup bluetooth subscriptions if using RaceBox
        if settingsManager.gpsSource == .raceBox {
            setupBluetoothSubscriptions()
        }
    }
    
    private func setupBluetoothSubscriptions() {
        guard let bluetoothManager = bluetoothManager else { return }
        
        // RaceBox connection state
        bluetoothManager.raceBoxManager.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                switch state {
                case .connected:
                    self?.hasGPSSignal = true
                default:
                    self?.hasGPSSignal = false
                }
            }
            .store(in: &cancellables)
        
        // RaceBox data
        bluetoothManager.raceBoxManager.$latestData
            .receive(on: RunLoop.main)
            .sink { [weak self] data in
                guard let self = self, let data = data else { return }
                
                // Only process data if we have a valid fix
                if data.hasValidFix {
                    self.hasGPSSignal = true
                    
                    // Update telemetry data
                    if self.settingsManager.unitSystem == .imperial {
                        self.speed = data.speedMPH
                        self.displaySpeed = data.speedMPH
                    } else {
                        self.speed = data.speedKPH
                        self.displaySpeed = data.speedKPH
                    }
                    
                    self.lateralG = data.gForceY
                    self.longitudinalG = data.gForceX
                    
                    // Process the data for lap/sector timing
                    let telemetryPoint = TelemetryData(fromRaceBoxData: data, sessionId: UUID())
                    self.sessionManager.processTelemetryData(telemetryPoint)
                } else {
                    self.hasGPSSignal = false
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupTelemetrySubscriptions() {
        // Subscribe to internal GPS if using that
        if settingsManager.gpsSource == .internal, let locationManager = locationManager {
            locationManager.$location
                .receive(on: RunLoop.main)
                .sink { [weak self] location in
                    guard let self = self, let location = location else { return }
                    
                    self.hasGPSSignal = true
                    
                    // Update telemetry data
                    let speed = max(0, location.speed)
                    if self.settingsManager.unitSystem == .imperial {
                        self.speed = speed * 2.23694 // m/s to mph
                        self.displaySpeed = self.speed
                    } else {
                        self.speed = speed * 3.6 // m/s to km/h
                        self.displaySpeed = self.speed
                    }
                    
                    // For internal GPS, lateral/longitudinal G data is not available
                    self.lateralG = 0
                    self.longitudinalG = 0
                    
                    // Process the data for lap/sector timing
                    let telemetryPoint = TelemetryData(fromLocation: location, sessionId: UUID())
                    self.sessionManager.processTelemetryData(telemetryPoint)
                }
                .store(in: &cancellables)
        }
        
        // Subscribe to OBD data if enabled
        if settingsManager.isOBDEnabled, let bluetoothManager = bluetoothManager {
            bluetoothManager.obdManager.$connectionState
                .receive(on: RunLoop.main)
                .sink { [weak self] state in
                    switch state {
                    case .connected:
                        self?.hasOBDConnection = true
                    default:
                        self?.hasOBDConnection = false
                    }
                }
                .store(in: &cancellables)
            
            bluetoothManager.obdManager.$vehicleData
                .receive(on: RunLoop.main)
                .sink { [weak self] vehicleData in
                    guard let self = self else { return }
                    
                    // Update OBD-related properties
                    if let rpm = vehicleData.rpm {
                        self.rpm = rpm
                    }
                    
                    if let throttlePos = vehicleData.throttlePosition {
                        self.throttlePosition = throttlePos
                    }
                    
                    // Estimate brake position based on deceleration
                    if let currentSpeed = self.lastSpeed,
                       let newSpeed = vehicleData.speed,
                       currentSpeed > newSpeed,
                       let timestamp = self.lastUpdateTime {
                        
                        let timeDelta = Date().timeIntervalSince(timestamp)
                        if timeDelta > 0 {
                            let deceleration = (currentSpeed - newSpeed) / timeDelta
                            // Scale deceleration to brake percentage (adjust thresholds as needed)
                            let maxDecel = 10.0 // m/s²
                            let brakePercentage = min(100, max(0, deceleration / maxDecel * 100))
                            self.brakePosition = brakePercentage
                        }
                    } else {
                        // If we're not decelerating, gradually reduce brake percentage
                        if self.brakePosition > 0 {
                            self.brakePosition = max(0, self.brakePosition - 5)
                        }
                    }
                    
                    // Update gear
                    if let gear = vehicleData.gear {
                        self.currentGear = String(gear)
                    } else {
                        self.currentGear = "N"
                    }
                    
                    // Store current speed for future comparisons
                    self.lastSpeed = vehicleData.speed
                    self.lastUpdateTime = Date()
                    
                    // Update vehicle data
                    self.updateVehicleData()
                }
                .store(in: &cancellables)
        }
        
        // Subscribe to session manager updates
        sessionManager.$currentLap
            .receive(on: RunLoop.main)
            .sink { [weak self] lapNumber in
                self?.currentLap = lapNumber
            }
            .store(in: &cancellables)
        
        sessionManager.$currentLapStartTime
            .receive(on: RunLoop.main)
            .sink { [weak self] startTime in
                self?.lapStartTime = startTime
                if startTime != nil {
                    self?.sector1Completed = false
                    self?.sector2Completed = false
                    self?.sector3Completed = false
                    self?.formattedSector1Time = "--:--"
                    self?.formattedSector2Time = "--:--"
                    self?.formattedSector3Time = "--:--"
                }
            }
            .store(in: &cancellables)
        
        sessionManager.$lastLapTime
            .receive(on: RunLoop.main)
            .sink { [weak self] lastLapTime in
                guard let self = self else { return }
                
                if let lastLapTime = lastLapTime {
                    self.lastLapTime = lastLapTime
                    self.formattedLastLapTime = self.formatLapTime(lastLapTime)
                }
            }
            .store(in: &cancellables)
        
        sessionManager.$bestLapTime
            .receive(on: RunLoop.main)
            .sink { [weak self] bestLapTime in
                guard let self = self else { return }
                
                if let bestLapTime = bestLapTime {
                    self.bestLapTime = bestLapTime
                    self.formattedBestLapTime = self.formatLapTime(bestLapTime)
                }
            }
            .store(in: &cancellables)
        
        sessionManager.$sector1Time
            .receive(on: RunLoop.main)
            .sink { [weak self] sector1Time in
                guard let self = self else { return }
                
                if let sector1Time = sector1Time {
                    self.sector1Time = sector1Time
                    self.sector1Completed = true
                    self.formattedSector1Time = self.formatSectorTime(sector1Time)
                    
                    // Check if it's the best sector time
                    if let bestSector1 = self.bestSector1Time {
                        self.isSector1Fastest = sector1Time < bestSector1
                        self.sector1Color = sector1Time < bestSector1 ? .green : .white
                    } else {
                        self.bestSector1Time = sector1Time
                        self.isSector1Fastest = true
                        self.sector1Color = .green
                    }
                }
            }
            .store(in: &cancellables)
        
        sessionManager.$sector2Time
            .receive(on: RunLoop.main)
            .sink { [weak self] sector2Time in
                guard let self = self else { return }
                
                if let sector2Time = sector2Time {
                    self.sector2Time = sector2Time
                    self.sector2Completed = true
                    self.formattedSector2Time = self.formatSectorTime(sector2Time)
                    
                    // Check if it's the best sector time
                    if let bestSector2 = self.bestSector2Time {
                        self.isSector2Fastest = sector2Time < bestSector2
                        self.sector2Color = sector2Time < bestSector2 ? .green : .white
                    } else {
                        self.bestSector2Time = sector2Time
                        self.isSector2Fastest = true
                        self.sector2Color = .green
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateVehicleData() {
        // Prioritize OBD speed data if available, otherwise use GPS speed
        if hasOBDConnection, let obdSpeed = bluetoothManager?.obdManager.vehicleData.speed {
            // Convert km/h to appropriate units
            if settingsManager.unitSystem == .imperial {
                speed = obdSpeed * 0.621371 // Convert to mph
                displaySpeed = speed
            } else {
                speed = obdSpeed
                displaySpeed = speed
            }
        }
        
        // Use OBD data for RPM, throttle, and gear when available
        if hasOBDConnection {
            let vehicleData = bluetoothManager?.obdManager.vehicleData
            
            if let rpm = vehicleData?.rpm {
                self.rpm = rpm
            }
            
            if let throttle = vehicleData?.throttlePosition {
                self.throttlePosition = throttle
            }
            
            if let gear = vehicleData?.gear {
                self.currentGear = String(gear)
            } else {
                self.currentGear = "N"
            }
        }
        
        // Always use RaceBox for G-force data if available
        if let raceBoxData = bluetoothManager?.raceBoxManager.latestData {
            lateralG = raceBoxData.gForceY
            longitudinalG = raceBoxData.gForceX
        }
    }
    
    private func startLapTimer() {
        currentLapTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateCurrentLapTime()
        }
    }
    
    private func stopLapTimer() {
        currentLapTimer?.invalidate()
        currentLapTimer = nil
    }
    
    private func updateCurrentLapTime() {
        guard let startTime = lapStartTime else {
            formattedCurrentLapTime = "00:00.000"
            return
        }
        
        let currentTime = Date()
        let elapsed = currentTime.timeIntervalSince(startTime)
        
        formattedCurrentLapTime = formatLapTime(elapsed)
        
        // Update delta to best lap
        if let bestLapTime = bestLapTime {
            currentLapDelta = elapsed - bestLapTime
            formattedDeltaTime = formatDeltaTime(currentLapDelta)
            isDeltaPositive = currentLapDelta > 0
        } else {
            formattedDeltaTime = "+00.000"
            isDeltaPositive = true
        }
    }
    
    private func updateUnitPreferences() {
        if settingsManager.unitSystem == .imperial {
            speedUnit = "MPH"
        } else {
            speedUnit = "KPH"
        }
    }
    
    private func resetSessionValues() {
        currentLap = 0
        lapStartTime = nil
        lastLapTime = nil
        bestLapTime = nil
        currentLapDelta = 0
        
        formattedCurrentLapTime = "00:00.000"
        formattedLastLapTime = "--:--.---"
        formattedBestLapTime = "--:--.---"
        formattedDeltaTime = "+00.000"
        isDeltaPositive = true
        
        sector1Time = nil
        sector2Time = nil
        sector3Time = nil
        bestSector1Time = nil
        bestSector2Time = nil
        bestSector3Time = nil
        
        sector1Completed = false
        sector2Completed = false
        sector3Completed = false
        
        formattedSector1Time = "--:--"
        formattedSector2Time = "--:--"
        formattedSector3Time = "--:--"
        
        isSector1Fastest = false
        isSector2Fastest = false
        isSector3Fastest = false
        
        sector1Color = .white
        sector2Color = .white
        sector3Color = .white
        
        // Set hasSectors based on track configuration
        hasSectors = (track?.sector1Point != nil) || (track?.sector2Point != nil)
    }
    
    // MARK: - Formatting Helpers
    
    private func formatLapTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    private func formatSectorTime(_ time: TimeInterval) -> String {
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d.%03d", seconds, milliseconds)
    }
    
    private func formatDeltaTime(_ time: TimeInterval) -> String {
        let sign = time >= 0 ? "+" : "-"
        let absTime = abs(time)
        
        let seconds = Int(absTime) % 60
        let milliseconds = Int((absTime.truncatingRemainder(dividingBy: 1)) * 1000)
        
        if seconds > 0 {
            return String(format: "%@%02d.%03d", sign, seconds, milliseconds)
        } else {
            return String(format: "%@00.%03d", sign, milliseconds)
        }
    }
}
