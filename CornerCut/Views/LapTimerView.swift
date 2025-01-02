import SwiftUI
import Combine
import SwiftData
import CoreLocation

struct LapTimerView: View {
    // MARK: - Environment & Observed Objects
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var obd2Manager: OBD2Manager
    @ObservedObject var raceBoxManager: RaceBoxManager
    
    @Bindable var session: Session
    
    // MARK: - State Properties
    @State private var timer: Timer?
    @State private var sessionActive = false
    
    @State private var currentLapStartTime = Date()
    @State private var currentLapNumber = 1
    @State private var currentLapTelemetry: [TelemetryData] = []
    
    // 25Hz for racebox
    private let captureInterval = 1.0 / 25.0
    
    var body: some View {
        VStack(spacing: 30) {
            
            Text("Lap \(currentLapNumber)")
                .font(.largeTitle)
                .bold()
            
            Text("Elapsed Time: \(elapsedTime(), format: .number.precision(.fractionLength(2))) s")
                .font(.title2)
            
            // Real-time metrics
            HStack(spacing: 40) {
                VStack {
                    Text("Speed")
                        .font(.headline)
                    Text("\(displaySpeed()) \(speedUnit())")
                        .font(.title3)
                }
                
                VStack {
                    Text("RPM")
                        .font(.headline)
                    Text("\(displayRPM(), format: .number)")
                        .font(.title3)
                }
            }
            
            // Start / Stop / Record Buttons
            HStack(spacing: 40) {
                Button(action: {
                    sessionActive ? endSession() : startSession()
                }, label: {
                    Text(sessionActive ? "End Session" : "Start Session")
                        .font(.title3)
                        .padding()
                        .foregroundColor(.white)
                        .background(sessionActive ? Color.red : Color.green)
                        .cornerRadius(8)
                })
                
                Button(action: {
                    recordLap()
                }, label: {
                    Text("Record Lap")
                        .font(.title3)
                        .padding()
                        .foregroundColor(.white)
                        .background(sessionActive ? Color.blue : Color.gray)
                        .cornerRadius(8)
                })
                .disabled(!sessionActive)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .navigationBarBackButtonHidden(true) // Hide the default back button if needed
        .onAppear {
            //Start location if needed
            locationManager.startUpdatingLocation()
            
            //If Racebox detected, use Racebox coding
            if session.usingExternalGPS {
                raceBoxManager.startReadingData()
            }
            
            //If using OBD2, start reading data (fill in later)
            //obd2Manager.startReadingData()
        }
        .onDisappear {
            //Stop managers when leaving view
            locationManager.stopUpdatingLocation()
            raceBoxManager.stopReadingData()
            //obd2Manager.stopReadingData()
        }
    }
}

// MARK: - Functions
extension LapTimerView {
    
    private func startSession() {
        sessionActive = true
        currentLapNumber = session.laps.count + 1
        currentLapStartTime = Date()
        currentLapTelemetry = []
        
        // Schedule a Timer at 25 Hz (interval = 0.04s)
        timer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { _ in
            captureTelemetry()
        }
    }
    
    private func endSession() {
        sessionActive = false
        timer?.invalidate()
        timer = nil
        
        //Record one final lap if needed
        recordLap()
    }
    
    private func recordLap() {
        //If we're not in a session, don't record
        guard sessionActive else { return }
        
        let lapEndTime = Date()
        let lapTime = lapEndTime.timeIntervalSince(currentLapStartTime)
        
        let newLap = Lap(lapNumber: currentLapNumber, lapTime: lapTime)
        //Append whatever was collected so far
        newLap.telemetryData.append(contentsOf: currentLapTelemetry)
        
        //Store to this Session
        session.laps.append(newLap)
        
        //Move to next lap
        currentLapNumber += 1
        currentLapStartTime = Date()
        currentLapTelemetry = []
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving lap data: \(error)")
        }
    }
    
    /// Called by the Timer every 1/25th second (25 Hz) for racebox (TODO: revert to 1hz for iPhone GPS option)
    private func captureTelemetry() {
        //Use RaceBox or phone’s GPS depending on user choice
        let lat: Double
        let lon: Double
        let speedVal: Double
        
        if session.usingExternalGPS {
            lat = raceBoxManager.latitude
            lon = raceBoxManager.longitude
            speedVal = raceBoxManager.currentSpeed
        } else {
            //Use iPhone Core Location
            let location = locationManager.currentLocation
            lat = location?.coordinate.latitude ?? 0
            lon = location?.coordinate.longitude ?? 0
            //iphone Location speed is in m/s by default
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
    
    private func elapsedTime() -> Double {
        guard sessionActive else { return 0 }
        return Date().timeIntervalSince(currentLapStartTime)
    }
    
    /// Displays speed as mph (for example).
    private func displaySpeed() -> String {
        let spd: Double
        if session.usingExternalGPS {
            spd = raceBoxManager.currentSpeed
        } else {
            spd = locationManager.currentLocation?.speed ?? 0
        }
        
        //Convert m/s to mph
        let mph = spd * 2.23694
        return String(format: "%.1f", mph)
    }
    
    private func displayRPM() -> Double {
        return obd2Manager.currentRPM
    }
    
    private func speedUnit() -> String {
        return "MPH"
    }
}
