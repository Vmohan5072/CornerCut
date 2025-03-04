import SwiftUI
import Combine
import SwiftData
import CoreLocation

struct LapTimerView: View {
    // MARK: - Environment & Observed Objects
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var obd2Manager: OBD2Manager
    @EnvironmentObject var raceBoxManager: RaceBoxManager
    
    @Bindable var session: Session
    
    // MARK: - State Properties
    @State private var timer: Timer?
    @State private var sessionActive = false
    @State private var currentLapStartTime = Date()
    @State private var currentLapNumber = 1
    @State private var currentLapTelemetry: [TelemetryData] = []
    @State private var bestLapTime: Double?
    @State private var lastLapTime: Double?
    @State private var deltaTime: Double?
    @State private var orientation = UIDeviceOrientation.portrait
    @State private var doubleTapActive = false
    
    // Capture frequency (25Hz for RaceBox, 10Hz for iPhone GPS)
    private let captureInterval: Double
    
    // Initialize with different capture rates depending on GPS source
    init(session: Session) {
        self.session = session
        self.captureInterval = session.usingExternalGPS ? 1.0 / 25.0 : 1.0 / 10.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Session content - adjust based on orientation
                if isLandscape(geometry: geometry) {
                    landscapeSessionView
                } else {
                    portraitSessionView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .statusBar(hidden: true)
        .onAppear {
            setupSessionOnAppear()
        }
        .onDisappear {
            teardownSessionOnDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            self.orientation = UIDevice.current.orientation
        }
        .onTapGesture(count: 2) {
            handleDoubleTap()
        }
    }
    
    // MARK: - Landscape View (Primary Race View)
    var landscapeSessionView: some View {
        ZStack {
            VStack {
                // Top row with lap count and best lap
                HStack {
                    // Lap count (top left)
                    SessionInfoBox(
                        title: "LAP",
                        value: "\(currentLapNumber)/\(max(1, session.laps.count))"
                    )
                    
                    Spacer()
                    
                    // Best Lap (top right)
                    SessionInfoBox(
                        title: "BEST LAP",
                        value: bestLapTime != nil ? formatTime(bestLapTime!) : "--:--.---"
                    )
                }
                .padding([.horizontal, .top])
                
                Spacer()
                
                // Bottom row with speed and RPM
                HStack {
                    // Speed (bottom left)
                    SessionInfoBox(
                        title: "SPEED",
                        value: "\(Int(displaySpeed())) \(speedUnit())"
                    )
                    
                    Spacer()
                    
                    // RPM (bottom right)
                    SessionInfoBox(
                        title: "RPM",
                        value: "\(Int(displayRPM()))"
                    )
                }
                .padding([.horizontal, .bottom])
            }
            
            // Center elements: Current lap time and delta
            VStack(spacing: 8) {
                // Current lap time - large text
                Text(elapsedTimeString())
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                // Delta to best lap time
                if let delta = deltaTime {
                    Text(formatDelta(delta))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(delta < 0 ? Color.green : Color.red)
                }
            }
            
            // Double tap indicator
            if doubleTapActive {
                Text("Double-tap to end session")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 30)
            }
        }
    }
    
    // MARK: - Portrait View
    var portraitSessionView: some View {
        VStack(spacing: 20) {
            // Top area - session info
            VStack(spacing: 8) {
                Text("Session: \(session.trackName)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Lap \(currentLapNumber)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.top)
            
            // Current Lap Time
            VStack(spacing: 4) {
                Text("Current Lap")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(elapsedTimeString())
                    .font(.system(size: 54, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                // Delta to best lap time
                if let delta = deltaTime {
                    Text(formatDelta(delta))
                        .font(.title3)
                        .foregroundColor(delta < 0 ? Color.green : Color.red)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6).opacity(0.2))
            .cornerRadius(10)
            
            // Best and Last Lap times
            HStack(spacing: 20) {
                VStack {
                    Text("Best Lap")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(bestLapTime != nil ? formatTime(bestLapTime!) : "--:--.---")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color(UIColor.systemGray6).opacity(0.2))
                .cornerRadius(10)
                
                VStack {
                    Text("Last Lap")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(lastLapTime != nil ? formatTime(lastLapTime!) : "--:--.---")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color(UIColor.systemGray6).opacity(0.2))
                .cornerRadius(10)
            }
            
            // Real-time metrics
            HStack {
                // Speed
                VStack {
                    Text("Speed")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(Int(displaySpeed())) \(speedUnit())")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.systemGray6).opacity(0.2))
                .cornerRadius(10)
                
                // RPM
                VStack {
                    Text("RPM")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(Int(displayRPM()))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.systemGray6).opacity(0.2))
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 20) {
                Button(action: {
                    sessionActive ? endSession() : startSession()
                }) {
                    HStack {
                        Image(systemName: sessionActive ? "stop.fill" : "play.fill")
                        Text(sessionActive ? "End Session" : "Start Session")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(sessionActive ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    recordLap()
                }) {
                    HStack {
                        Image(systemName: "flag.fill")
                        Text("Record Lap")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(sessionActive ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!sessionActive)
            }
            .padding(.bottom)
        }
        .padding()
        .background(Color.black)
    }
}

// MARK: - Session Management Functions
extension LapTimerView {
    private func setupSessionOnAppear() {
        // Start location if needed
        locationManager.startUpdatingLocation()
        
        // If RaceBox detected, use RaceBox coding
        if session.usingExternalGPS {
            raceBoxManager.startReadingData()
        }
        
        // Start OBD2 data if available
        obd2Manager.startReadingData()
        
        // Extract best lap time if any exist
        updateBestLapTime()
    }
    
    private func teardownSessionOnDisappear() {
        endSession()
        locationManager.stopUpdatingLocation()
        raceBoxManager.stopReadingData()
        obd2Manager.stopReadingData()
    }
    
    private func startSession() {
        sessionActive = true
        currentLapNumber = session.laps.count + 1
        currentLapStartTime = Date()
        currentLapTelemetry = []
        lastLapTime = nil
        
        // Schedule telemetry capture timer
        timer = Timer.scheduledTimer(
            withTimeInterval: captureInterval,
            repeats: true
        ) { _ in
            captureTelemetry()
            updateDeltaTime()
        }
    }
    
    private func endSession() {
        guard sessionActive else { return }
        
        sessionActive = false
        timer?.invalidate()
        timer = nil
        
        // Record the current lap if needed
        if !currentLapTelemetry.isEmpty {
            recordLap()
        }
        
        // Save session
        do {
            try modelContext.save()
        } catch {
            print("Error saving session data: \(error)")
        }
    }
    
    private func recordLap() {
        // If we're not in a session, don't record
        guard sessionActive else { return }
        
        let lapEndTime = Date()
        let lapTime = lapEndTime.timeIntervalSince(currentLapStartTime)
        
        // Create new lap
        let newLap = Lap(lapNumber: currentLapNumber, lapTime: lapTime)
        
        // Append telemetry data
        newLap.telemetryData.append(contentsOf: currentLapTelemetry)
        
        // Store to session
        session.laps.append(newLap)
        
        // Update last and best lap times
        lastLapTime = lapTime
        updateBestLapTime()
        
        // Move to next lap
        currentLapNumber += 1
        currentLapStartTime = Date()
        currentLapTelemetry = []
        
        // Save to database
        do {
            try modelContext.save()
        } catch {
            print("Error saving lap data: \(error)")
        }
    }
    
    private func updateBestLapTime() {
        // Find best lap time from existing laps
        if !session.laps.isEmpty {
            bestLapTime = session.laps.min(by: { $0.lapTime < $1.lapTime })?.lapTime
        }
    }
    
    private func updateDeltaTime() {
        guard sessionActive, let best = bestLapTime else { return }
        
        let currentElapsed = elapsedTime()
        
        // Calculate the corresponding time in the best lap
        // This is a simplistic approach - for accurate delta time,
        // you would need to compare based on distance/position on track
        if currentElapsed <= best {
            // We're still within the best lap time range
            deltaTime = currentElapsed - best
        }
    }
    
    private func handleDoubleTap() {
        if sessionActive {
            // Toggle the double tap indicator first time
            if !doubleTapActive {
                doubleTapActive = true
                
                // Hide the indicator after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.doubleTapActive = false
                }
            } else {
                // Second double tap - end the session
                endSession()
                dismiss()
            }
        }
    }
}

// MARK: - Telemetry Capture
extension LapTimerView {
    /// Captures current telemetry data at the timer interval
    private func captureTelemetry() {
        // Get location data from RaceBox or iPhone
        let lat: Double
        let lon: Double
        let speedVal: Double
        
        if session.usingExternalGPS {
            lat = raceBoxManager.latitude
            lon = raceBoxManager.longitude
            speedVal = raceBoxManager.currentSpeed
        } else {
            // Use iPhone Core Location
            let location = locationManager.currentLocation
            lat = location?.coordinate.latitude ?? 0
            lon = location?.coordinate.longitude ?? 0
            // iPhone Location speed is in m/s by default
            speedVal = location?.speed ?? 0
        }
        
        // OBD2 data
        let rpmVal = obd2Manager.currentRPM
        let throttleVal = obd2Manager.throttle
        
        // Create new TelemetryData
        let telemetry = TelemetryData(
            timestamp: Date(),
            speed: speedVal,
            rpm: rpmVal,
            throttle: throttleVal,
            latitude: lat,
            longitude: lon
        )
        
        // Append to current in-memory array
        currentLapTelemetry.append(telemetry)
    }
}

// MARK: - Helper Functions
extension LapTimerView {
    /// Returns current elapsed time in seconds
    private func elapsedTime() -> Double {
        guard sessionActive else { return 0 }
        return Date().timeIntervalSince(currentLapStartTime)
    }
    
    /// Returns formatted elapsed time string (MM:SS.sss)
    private func elapsedTimeString() -> String {
        return formatTime(elapsedTime())
    }
    
    /// Formats time in seconds to MM:SS.sss
    private func formatTime(_ timeSeconds: Double) -> String {
        let minutes = Int(timeSeconds) / 60
        let seconds = Int(timeSeconds) % 60
        let milliseconds = Int((timeSeconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%01d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    /// Formats delta time with +/- sign
    private func formatDelta(_ delta: Double) -> String {
        let sign = delta < 0 ? "-" : "+"
        let absValue = abs(delta)
        
        let minutes = Int(absValue) / 60
        let seconds = Int(absValue) % 60
        let milliseconds = Int((absValue.truncatingRemainder(dividingBy: 1)) * 1000)
        
        if minutes > 0 {
            return String(format: "%@%01d:%02d.%03d", sign, minutes, seconds, milliseconds)
        } else {
            return String(format: "%@%02d.%03d", sign, seconds, milliseconds)
        }
    }
    
    /// Returns current speed in appropriate unit
    private func displaySpeed() -> Double {
        let speedMS: Double
        
        if session.usingExternalGPS {
            speedMS = raceBoxManager.currentSpeed
        } else {
            speedMS = locationManager.currentLocation?.speed ?? 0
        }
        
        // Convert m/s to mph
        return speedMS * 2.23694
    }
    
    /// Returns current RPM
    private func displayRPM() -> Double {
        return obd2Manager.currentRPM
    }
    
    /// Returns speed unit string
    private func speedUnit() -> String {
        return "MPH"
    }
    
    /// Determines if device is in landscape orientation
    private func isLandscape(geometry: GeometryProxy) -> Bool {
        return geometry.size.width > geometry.size.height
    }
}

// MARK: - Supporting View Components

/// Box for displaying session info with title and value
struct SessionInfoBox: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.2))
        .cornerRadius(10)
    }
}
