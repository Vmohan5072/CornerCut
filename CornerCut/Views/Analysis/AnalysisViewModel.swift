//
//  AnalysisViewModel.swift
//  CornerCut
//

import Foundation
import Combine
import SwiftUI

class AnalysisViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedSession: LapSession?
    @Published var selectedLap: LapData?
    @Published var telemetryData: [TelemetryData] = []
    @Published var comparisonLap: LapData?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Analysis Data
    
    @Published var speedPoints: [ChartPoint] = []
    @Published var rpmPoints: [ChartPoint] = []
    @Published var throttlePoints: [ChartPoint] = []
    @Published var brakePoints: [ChartPoint] = []
    @Published var lateralGPoints: [ChartPoint] = []
    @Published var longitudinalGPoints: [ChartPoint] = []
    
    // MARK: - Metrics
    
    @Published var maxSpeed: Double = 0
    @Published var avgSpeed: Double = 0
    @Published var maxRPM: Double = 0
    @Published var avgRPM: Double = 0
    @Published var maxThrottle: Double = 0
    @Published var avgThrottle: Double = 0
    @Published var maxBrake: Double = 0
    @Published var maxLateralG: Double = 0
    @Published var maxLongitudinalG: Double = 0
    @Published var throttleTime: TimeInterval = 0
    @Published var brakeTime: TimeInterval = 0
    @Published var coastTime: TimeInterval = 0
    
    // MARK: - Dependencies
    
    private let sessionManager = SessionManager.shared
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    func loadSession(_ session: LapSession) {
        self.selectedSession = session
        
        // Load the best lap by default
        if let bestLap = session.bestLap {
            loadLap(bestLap)
        } else if !session.laps.isEmpty {
            loadLap(session.laps.first!)
        }
    }
    
    func loadLap(_ lap: LapData) {
        isLoading = true
        selectedLap = lap
        
        // This would be implemented to load telemetry data from storage
        // For now we'll just simulate some data
        loadTelemetryData(for: lap) { [weak self] data in
            guard let self = self else { return }
            
            self.telemetryData = data
            self.processLapData()
            self.isLoading = false
        }
    }
    
    func setComparisonLap(_ lap: LapData?) {
        comparisonLap = lap
        // If we had a comparison lap, we would process its data here
    }
    
    // MARK: - Private Methods
    
    private func loadTelemetryData(for lap: LapData, completion: @escaping ([TelemetryData]) -> Void) {
        // In a real implementation, this would load from disk or database
        // For now, let's just create some sample data
        var sampleData: [TelemetryData] = []
        
        // Create some simulated telemetry data points over the lap time
        let lapDuration = lap.lapTime
        let pointCount = 100 // Number of data points to generate
        let timeStep = lapDuration / Double(pointCount)
        
        for i in 0..<pointCount {
            let timestamp = Date().addingTimeInterval(-lapDuration + (Double(i) * timeStep))
            let progress = Double(i) / Double(pointCount)
            
            // Create some sample patterns (simplified for demo)
            let speed = 50 + 80 * sin(progress * .pi * 2) // Speed varies from 50 to 130 kph
            let rpm = 2000 + 4000 * sin(progress * .pi * 2) // RPM varies from 2000 to 6000
            let throttle = max(0, 50 + 50 * sin(progress * .pi * 2)) // Throttle varies from 0 to 100%
            let brake = max(0, -50 + 50 * sin(progress * .pi * 2)) // Brake is inverse of throttle
            
            // Create a sample point
            let coordinate = CLLocationCoordinate2D(latitude: 37.3352 + progress * 0.01,
                                                   longitude: -121.8811 + progress * 0.01)
            
            let point = TelemetryData(
                id: UUID(),
                sessionId: UUID(), // This would be the actual session ID in real code
                lapId: lap.id,
                timestamp: timestamp,
                location: GeoPoint(coordinate: coordinate),
                speed: speed / 3.6, // Convert kph to m/s
                heading: 0,
                altitude: 0,
                gForceX: max(-2, min(2, sin(progress * .pi * 4))), // Longitudinal G
                gForceY: max(-2, min(2, cos(progress * .pi * 4))), // Lateral G
                gForceZ: 1.0, // Vertical G (mostly constant)
                rotationRateX: 0,
                rotationRateY: 0,
                rotationRateZ: 0,
                engineRPM: rpm,
                throttlePosition: throttle,
                brakePosition: brake,
                gear: Int(1 + progress * 5) // Cycle through gears 1-6
            )
            
            sampleData.append(point)
        }
        
        // Return the sample data after a short delay to simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(sampleData)
        }
    }
    
    private func processLapData() {
        guard !telemetryData.isEmpty else { return }
        
        // Reset chart arrays
        speedPoints = []
        rpmPoints = []
        throttlePoints = []
        brakePoints = []
        lateralGPoints = []
        longitudinalGPoints = []
        
        // Process each telemetry point
        var totalSpeed = 0.0
        var totalRPM = 0.0
        var totalThrottle = 0.0
        var maxSpeedVal = 0.0
        var maxRPMVal = 0.0
        var maxThrottleVal = 0.0
        var maxBrakeVal = 0.0
        var maxLatGVal = 0.0
        var maxLongGVal = 0.0
        var throttleTimeVal = 0.0
        var brakeTimeVal = 0.0
        var coastTimeVal = 0.0
        
        // Get first timestamp for relative time
        let startTime = telemetryData.first!.timestamp
        
        // Process each point
        for i in 0..<telemetryData.count {
            let point = telemetryData[i]
            
            // Calculate elapsed time from start
            let elapsed = point.timestamp.timeIntervalSince(startTime)
            
            // Add data points
            if settingsManager.unitSystem == .imperial {
                speedPoints.append(ChartPoint(x: elapsed, y: point.getSpeedMPH()))
            } else {
                speedPoints.append(ChartPoint(x: elapsed, y: point.getSpeedKPH()))
            }
            
            if let rpm = point.engineRPM {
                rpmPoints.append(ChartPoint(x: elapsed, y: rpm))
                totalRPM += rpm
                maxRPMVal = max(maxRPMVal, rpm)
            }
            
            if let throttle = point.throttlePosition {
                throttlePoints.append(ChartPoint(x: elapsed, y: throttle))
                totalThrottle += throttle
                maxThrottleVal = max(maxThrottleVal, throttle)
                
                // Count time spent on throttle (simplified)
                if throttle > 5 {
                    throttleTimeVal += elapsed / Double(telemetryData.count)
                }
            }
            
            if let brake = point.brakePosition {
                brakePoints.append(ChartPoint(x: elapsed, y: brake))
                maxBrakeVal = max(maxBrakeVal, brake)
                
                // Count time spent on brake (simplified)
                if brake > 5 {
                    brakeTimeVal += elapsed / Double(telemetryData.count)
                }
            }
            
            // G-force data
            let latG = point.getLateralGForce()
            let longG = point.getLongitudinalGForce()
            
            lateralGPoints.append(ChartPoint(x: elapsed, y: latG))
            longitudinalGPoints.append(ChartPoint(x: elapsed, y: longG))
            
            maxLatGVal = max(maxLatGVal, abs(latG))
            maxLongGVal = max(maxLongGVal, abs(longG))
            
            // Speed stats
            if settingsManager.unitSystem == .imperial {
                totalSpeed += point.getSpeedMPH()
                maxSpeedVal = max(maxSpeedVal, point.getSpeedMPH())
            } else {
                totalSpeed += point.getSpeedKPH()
                maxSpeedVal = max(maxSpeedVal, point.getSpeedKPH())
            }
            
            // Count coasting time (neither throttle nor brake)
            if (point.throttlePosition ?? 0) < 5 && (point.brakePosition ?? 0) < 5 {
                coastTimeVal += elapsed / Double(telemetryData.count)
            }
        }
        
        // Update summary metrics
        maxSpeed = maxSpeedVal
        avgSpeed = totalSpeed / Double(telemetryData.count)
        maxRPM = maxRPMVal
        avgRPM = totalRPM / Double(rpmPoints.count)
        maxThrottle = maxThrottleVal
        avgThrottle = totalThrottle / Double(throttlePoints.count)
        maxBrake = maxBrakeVal
        maxLateralG = maxLatGVal
        maxLongitudinalG = maxLongGVal
        throttleTime = throttleTimeVal
        brakeTime = brakeTimeVal
        coastTime = coastTimeVal
    }
}

// MARK: - Chart Data Structure

struct ChartPoint: Identifiable {
    var id = UUID()
    var x: Double // Time
    var y: Double // Value
}
