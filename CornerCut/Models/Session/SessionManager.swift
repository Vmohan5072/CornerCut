//
//  SessionManager.swift
//  RaceBoxLapTimer
//

import Foundation
import Combine
import CoreLocation

class SessionManager {
    // MARK: - Singleton
    
    static let shared = SessionManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var sessions: [LapSession] = []
    @Published private(set) var currentSession: LapSession?
    @Published private(set) var isRecording = false
    @Published private(set) var currentLap: Int = 0
    @Published private(set) var currentLapStartTime: Date?
    @Published private(set) var lastLapTime: TimeInterval?
    @Published private(set) var bestLapTime: TimeInterval?
    @Published private(set) var sector1Time: TimeInterval?
    @Published private(set) var sector2Time: TimeInterval?
    @Published private(set) var sector1CrossTime: Date?
    @Published private(set) var sector2CrossTime: Date?
    
    // MARK: - Private Properties
    
    private var telemetryBuffer: [TelemetryData] = []
    private var lapBuffer: [TelemetryData] = []
    private var dateFormatter: DateFormatter
    private var tempSessionId: UUID?
    private var lastPosition: CLLocationCoordinate2D?
    private var isInStartZone = false
    private var lastStartZoneExitTime: Date?
    private var crossingStartLine = false
    private var crossingSector1 = false
    private var crossingSector2 = false
    private var fileManager = FileManager.default
    
    // MARK: - Initialization
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        loadSessions()
    }
    
    // MARK: - Public Methods
    
    func getAllSessions() -> [LapSession] {
        return sessions.sorted(by: { $0.startTime > $1.startTime })
    }
    
    func getSession(id: UUID) -> LapSession? {
        return sessions.first(where: { $0.id == id })
    }
    
    func getSessionsForTrack(trackId: UUID) -> [LapSession] {
        return sessions.filter { $0.trackId == trackId }
              .sorted(by: { $0.startTime > $1.startTime })
    }
    
    func startSession(track: Track, sessionType: SessionType) {
        // Create a new session
        let sessionId = UUID()
        tempSessionId = sessionId
        
        currentSession = LapSession(
            id: sessionId,
            trackId: track.id,
            trackName: track.name,
            sessionType: sessionType
        )
        
        // Reset state
        currentLap = 0
        currentLapStartTime = nil
        lastLapTime = nil
        bestLapTime = nil
        sector1Time = nil
        sector2Time = nil
        sector1CrossTime = nil
        sector2CrossTime = nil
        telemetryBuffer = []
        lapBuffer = []
        lastPosition = nil
        isInStartZone = false
        lastStartZoneExitTime = nil
        crossingStartLine = false
        crossingSector1 = false
        crossingSector2 = false
        
        isRecording = true
        
        // Update track usage
        TrackManager.shared.updateTrackUsage(id: track.id)
    }
    
    func endSession() {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        sessions.append(session)
        saveSessions()
        
        isRecording = false
        currentSession = nil
        tempSessionId = nil
        
        // If the last lap was incomplete, finalize it as invalid
        if currentLapStartTime != nil {
            // Mark as invalid, but we could potentially save it as a partial lap
            currentLapStartTime = nil
        }
        
        // Save telemetry data if needed
        saveTelemetryData()
    }
    
    func processTelemetryData(_ data: TelemetryData) {
        guard isRecording, let session = currentSession, let sessionId = tempSessionId else { return }
        
        // Add data to telemetry buffer
        let telemetryPoint = TelemetryData(
            id: UUID(),
            sessionId: sessionId,
            lapId: nil, // Will be assigned later when the lap is finalized
            timestamp: data.timestamp,
            location: data.location,
            speed: data.speed,
            heading: data.heading,
            altitude: data.altitude,
            gForceX: data.gForceX,
            gForceY: data.gForceY,
            gForceZ: data.gForceZ,
            rotationRateX: data.rotationRateX,
            rotationRateY: data.rotationRateY,
            rotationRateZ: data.rotationRateZ,
            engineRPM: data.engineRPM,
            throttlePosition: data.throttlePosition,
            brakePosition: data.brakePosition,
            gear: data.gear,
            engineTemp: data.engineTemp,
            oilTemp: data.oilTemp,
            oilPressure: data.oilPressure,
            fuelLevel: data.fuelLevel,
            boost: data.boost
        )
        
        telemetryBuffer.append(telemetryPoint)
        
        // If we're on a lap, add to lap buffer
        if currentLapStartTime != nil {
            lapBuffer.append(telemetryPoint)
        }
        
        // Process for track position and lap/sector detection
        detectTrackEvents(telemetryPoint, track: TrackManager.shared.getTrack(id: session.trackId))
        
        // Clean up old data if buffer gets too large
        if telemetryBuffer.count > 10000 {
            saveTelemetryData()
            telemetryBuffer = []
        }
    }
    
    // MARK: - Private Methods
    
    private func detectTrackEvents(_ data: TelemetryData, track: Track?) {
        guard let track = track else { return }
        
        // Check proximity to start/finish line
        let startFinishPoint = track.startFinishLine.point
        let distanceToStart = data.location.distance(to: startFinishPoint)
        
        // Check proximity to sector points if defined
        if let sector1Point = track.sector1Point {
            let distanceToSector1 = data.location.distance(to: sector1Point)
            
            if distanceToSector1 < 15 && !crossingSector1 {  // Within 15 meters of sector 1 point
                crossingSector1 = true
                
                // If we're on a lap, record sector time
                if let lapStartTime = currentLapStartTime {
                    sector1Time = data.timestamp.timeIntervalSince(lapStartTime)
                    sector1CrossTime = data.timestamp
                }
            } else if distanceToSector1 > 20 {
                crossingSector1 = false
            }
        }
        
        if let sector2Point = track.sector2Point {
            let distanceToSector2 = data.location.distance(to: sector2Point)
            
            if distanceToSector2 < 15 && !crossingSector2 {  // Within 15 meters of sector 2 point
                crossingSector2 = true
                
                // If we're on a lap and have crossed sector 1, record sector 2 time
                if let sector1CrossTime = sector1CrossTime {
                    sector2Time = data.timestamp.timeIntervalSince(sector1CrossTime)
                    sector2CrossTime = data.timestamp
                }
            } else if distanceToSector2 > 20 {
                crossingSector2 = false
            }
        }
        
        // Start/finish line detection logic
        let startFinishWidth = track.startFinishLine.width
        
        if track.type == .circuit {
            // For circuits, we use a geofence around the start/finish line
            // When we enter the zone, set isInStartZone to true
            // When we exit, set lastStartZoneExitTime and isInStartZone to false
            // If we enter again after exiting, and enough time has passed, it's a new lap
            
            if distanceToStart < startFinishWidth / 2 {
                // We're in the start/finish zone
                if !isInStartZone {
                    // Just entered the zone
                    isInStartZone = true
                    
                    // If we're coming back around and have a lastStartZoneExitTime
                    if let exitTime = lastStartZoneExitTime,
                       let startTime = currentLapStartTime,
                       data.timestamp.timeIntervalSince(exitTime) > 10 {  // Ensure we've done at least 10 seconds of a lap
                        
                        // Complete this lap
                        let lapTime = data.timestamp.timeIntervalSince(startTime)
                        completeLap(endTime: data.timestamp, lapTime: lapTime)
                        
                        // Start a new lap
                        startNewLap(data.timestamp)
                    } else if currentLapStartTime == nil {
                        // First lap of the session
                        startNewLap(data.timestamp)
                    }
                }
            } else if distanceToStart > startFinishWidth {
                // We're outside the start/finish zone
                if isInStartZone {
                    // Just exited the zone
                    isInStartZone = false
                    lastStartZoneExitTime = data.timestamp
                }
            }
        } else if track.type == .pointToPoint {
            // For point-to-point tracks, we check for crossing start and end lines
            
            // TODO: Implement point-to-point logic with separate start and end points
        }
    }
    
    private func startNewLap(_ startTime: Date) {
        currentLap += 1
        currentLapStartTime = startTime
        sector1Time = nil
        sector2Time = nil
        sector1CrossTime = nil
        sector2CrossTime = nil
        lapBuffer = []
    }
    
    private func completeLap(endTime: Date, lapTime: TimeInterval) {
        guard var session = currentSession,
              let lapStartTime = currentLapStartTime else { return }
        
        // Create the lap data
        let lap = LapData(
            lapNumber: currentLap,
            lapTime: lapTime,
            sector1Time: sector1Time,
            sector2Time: sector2Time,
            sector3Time: sector2CrossTime != nil ? endTime.timeIntervalSince(sector2CrossTime!) : nil,
            maxSpeed: lapBuffer.maxSpeed(),
            averageSpeed: lapBuffer.averageSpeed(),
            isValid: true
        )
        
        // Add to session
        session.laps.append(lap)
        currentSession = session
        
        // Update best lap time
        lastLapTime = lapTime
        if bestLapTime == nil || lapTime < bestLapTime! {
            bestLapTime = lapTime
            
            // Update track best lap time if this is a new record
            if let track = TrackManager.shared.getTrack(id: session.trackId) {
                if track.bestLapTime == nil || lapTime < track.bestLapTime! {
                    TrackManager.shared.updateTrackUsage(id: track.id, bestLapTime: lapTime)
                }
            }
        }
        
        // Save lap telemetry data
        saveLapTelemetryData(lap.id)
    }
    
    private func saveLapTelemetryData(_ lapId: UUID) {
        // Update lap ID for telemetry points in this lap
        for i in 0..<lapBuffer.count {
            lapBuffer[i].lapId = lapId
        }
        
        // Save telemetry data for this lap
        // (In a real app, you'd persist this to disk or database)
        
        // Clear lap buffer
        lapBuffer = []
    }
    
    private func saveTelemetryData() {
        // Save telemetry data to disk
        // (In a real app, you'd implement proper persistence)
    }
    
    private func loadSessions() {
        // Load sessions from disk
        // (In a real app, you'd implement proper persistence)
        sessions = []
    }
    
    private func saveSessions() {
        // Save sessions to disk
        // (In a real app, you'd implement proper persistence)
    }
}
