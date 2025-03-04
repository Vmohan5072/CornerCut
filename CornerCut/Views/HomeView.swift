import SwiftUI
import SwiftData

struct HomeView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var raceBoxManager: RaceBoxManager
    @EnvironmentObject private var obd2Manager: OBD2Manager
    
    // SwiftData Query
    @Query(sort: \Session.date, order: .reverse) private var recentSessions: [Session]
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    @State private var showingTrackList = false
    @State private var showingCustomSessionType = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Start Card
                    VStack(spacing: 16) {
                        HStack {
                            Text("Quick Start")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        // Circuit Session Button
                        Button {
                            showingTrackList = true
                        } label: {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .font(.headline)
                                Text("Start Circuit Session")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // Custom Session Button
                        Button {
                            showingCustomSessionType = true
                        } label: {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.headline)
                                Text("Start Custom Session")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Recent Sessions
                    VStack(spacing: 16) {
                        HStack {
                            Text("Recent Sessions")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            NavigationLink(destination: SessionsView()) {
                                Text("View All")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if recentSessions.isEmpty {
                            HStack {
                                Spacer()
                                Text("No recent sessions")
                                    .foregroundColor(.gray)
                                    .padding()
                                Spacer()
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        } else {
                            // Only show up to 3 most recent sessions
                            ForEach(Array(recentSessions.prefix(3).enumerated()), id: \.element.id) { index, session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    RecentSessionRow(session: session)
                                }
                                
                                if index < min(recentSessions.count, 3) - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Device Status Card
                    VStack(spacing: 16) {
                        HStack {
                            Text("Device Status")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        // RaceBox Status
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.title3)
                                .foregroundColor(raceBoxManager.isConnected ? .green : .gray)
                            
                            VStack(alignment: .leading) {
                                Text("RaceBox GPS")
                                    .fontWeight(.medium)
                                
                                if raceBoxManager.isConnected {
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("Not Connected")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                connectRaceBox()
                            } label: {
                                Text(raceBoxManager.isConnected ? "Disconnect" : "Connect")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(raceBoxManager.isConnected ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundColor(raceBoxManager.isConnected ? .red : .blue)
                                    .cornerRadius(20)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        
                        // OBD Status
                        HStack {
                            Image(systemName: "car")
                                .font(.title3)
                                .foregroundColor(obd2Manager.isDeviceConnected ? .green : .gray)
                            
                            VStack(alignment: .leading) {
                                Text("OBD2 Reader")
                                    .fontWeight(.medium)
                                
                                if obd2Manager.isDeviceConnected {
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("Not Connected")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                connectOBD()
                            } label: {
                                Text(obd2Manager.isDeviceConnected ? "Disconnect" : "Connect")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(obd2Manager.isDeviceConnected ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundColor(obd2Manager.isDeviceConnected ? .red : .blue)
                                    .cornerRadius(20)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("CornerCut")
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Connecting...")
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        }
                        .padding(20)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(10)
                    }
                    .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showingTrackList) {
                NavigationView {
                    TrackListView(onTrackSelected: { trackName in
                        showingTrackList = false
                        startCircuitSession(trackName: trackName)
                    })
                }
            }
            .sheet(isPresented: $showingCustomSessionType) {
                NavigationView {
                    CustomSessionTypeView { sessionType, pointA, pointB in
                        showingCustomSessionType = false
                        startCustomSession(type: sessionType, pointA: pointA, pointB: pointB)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Functions
    
    private func connectRaceBox() {
        isLoading = true
        
        if raceBoxManager.isConnected {
            raceBoxManager.stopReadingData()
            isLoading = false
        } else {
            raceBoxManager.startReadingData()
            
            // Set a timeout to stop loading indicator
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                isLoading = false
            }
        }
    }
    
    private func connectOBD() {
        isLoading = true
        
        if obd2Manager.isDeviceConnected {
            obd2Manager.stopReadingData()
            isLoading = false
        } else {
            obd2Manager.startReadingData()
            
            // Set a timeout to stop loading indicator
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                isLoading = false
            }
        }
    }
    
    private func startCircuitSession(trackName: String) {
        // Create a new session for a circuit track
        let newSession = Session(
            trackName: trackName,
            usingExternalGPS: raceBoxManager.isConnected,
            date: Date()
        )
        
        // Save to database
        modelContext.insert(newSession)
        
        // Start the session
        startTimerForSession(newSession)
    }
    
    private func startCustomSession(type: CustomSessionType, pointA: CLLocationCoordinate2D?, pointB: CLLocationCoordinate2D?) {
        // For custom sessions, we use a different naming convention
        let typeName: String
        
        switch type {
        case .singlePoint:
            typeName = "Single Point"
        case .pointToPoint:
            typeName = "Point to Point"
        }
        
        let newSession = Session(
            trackName: "Custom: \(typeName)",
            usingExternalGPS: raceBoxManager.isConnected,
            customName: "Custom Session \(Date().formatted(date: .abbreviated, time: .shortened))",
            date: Date()
        )
        
        // Save to database
        modelContext.insert(newSession)
        
        // Store custom points if needed (you would need to add these fields to your Session model)
        // newSession.startPoint = pointA
        // newSession.endPoint = pointB
        
        // Start the session
        startTimerForSession(newSession)
    }
    
    private func startTimerForSession(_ session: Session) {
        // Navigate to the LapTimerView
        let hostedLapTimerView = UIHostingController(rootView:
            LapTimerView(session: session)
                .environmentObject(locationManager)
                .environmentObject(raceBoxManager)
                .environmentObject(obd2Manager)
        )
        
        // Make it full screen
        hostedLapTimerView.modalPresentationStyle = .fullScreen
        
        // Present it
        UIApplication.shared.windows.first?.rootViewController?.present(hostedLapTimerView, animated: true)
    }
}

// MARK: - Supporting Views

struct RecentSessionRow: View {
    let session: Session
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.trackName)
                    .font(.headline)
                
                Text(session.date, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let bestLapTime = findBestLapTime()
                
                Text(bestLapTime != nil ? formatTime(bestLapTime!) : "No laps")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("\(session.laps.count) laps")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func findBestLapTime() -> Double? {
        guard !session.laps.isEmpty else { return nil }
        return session.laps.min(by: { $0.lapTime < $1.lapTime })?.lapTime
    }
    
    private func formatTime(_ timeSeconds: Double) -> String {
        let minutes = Int(timeSeconds) / 60
        let seconds = Int(timeSeconds) % 60
        let milliseconds = Int((timeSeconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%01d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - LocationManager Dummy for Preview
class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
}
