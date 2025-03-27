//
//  HomeView.swift
//  CornerCut
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var bluetoothManager: BluetoothManager
    @EnvironmentObject private var locationManager: LocationManager
    @State private var showingSessionOptions = false
    @State private var selectedTrack: Track?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick start section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Start")
                        .font(.headline)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(radius: 5)
                        
                        VStack(spacing: 16) {
                            Image(systemName: "flag.checkered.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            
                            Text("Start Lap Session")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                if !viewModel.favoriteTracks.isEmpty {
                                    selectedTrack = viewModel.favoriteTracks[0]
                                    showingSessionOptions = true
                                } else {
                                    // Navigate to track selection
                                }
                            }) {
                                Text("Track Mode")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    .frame(height: 200)
                }
                .padding(.horizontal)
                
                // Connection status
                ConnectionStatusView(
                    gpsConnected: locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways,
                    obdConnected: false, // This would be from BluetoothManager's OBD state
                    gpsSource: SettingsManager.shared.gpsSource
                )
                .padding(.horizontal)
                
                // Recent sessions
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Sessions")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: SessionHistoryView()) {
                            Text("See All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if viewModel.recentSessions.isEmpty {
                        Text("No recent sessions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.recentSessions) { session in
                                    NavigationLink(destination: SessionReviewView(session: session)) {
                                        RecentSessionCard(session: session)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Favorite tracks
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Favorite Tracks")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: TrackListView()) {
                            Text("See All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if viewModel.favoriteTracks.isEmpty {
                        Text("No favorite tracks")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.favoriteTracks) { track in
                                    NavigationLink(destination: TrackDetailView(track: track)) {
                                        FavoriteTrackCard(track: track)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.horizontal)
                
                // User stats
                UserStatsView(stats: viewModel.stats)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            .padding(.top)
        }
        .navigationTitle("CornerCut")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.refreshData()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        .actionSheet(isPresented: $showingSessionOptions) {
            ActionSheet(
                title: Text("Start Session"),
                message: Text("Select a session type" + (selectedTrack != nil ? " for \(selectedTrack!.name)" : "")),
                buttons: [
                    .default(Text("Practice")) {
                        startSession(type: .practice)
                    },
                    .default(Text("Qualifying")) {
                        startSession(type: .qualifying)
                    },
                    .default(Text("Race")) {
                        startSession(type: .race)
                    },
                    .default(Text("Testing")) {
                        startSession(type: .testing)
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func startSession(type: SessionType) {
        guard let track = selectedTrack else { return }
        
        // Create a view model for the session
        let sessionViewModel = SessionViewModel(
            bluetoothManager: bluetoothManager,
            locationManager: locationManager
        )
        
        // Start the session with the selected track and type
        sessionViewModel.startSession(track: track, sessionType: type)
        
        // In a real implementation, we would navigate to the active session view
        // This would require a coordinator pattern or another navigation approach
        print("Starting \(type.rawValue) session on \(track.name)")
    }
}

struct ConnectionStatusView: View {
    let gpsConnected: Bool
    let obdConnected: Bool
    let gpsSource: GPSSource
    
    var body: some View {
        HStack(spacing: 20) {
            // GPS status
            StatusIndicator(
                icon: "location.fill",
                title: "GPS",
                subtitle: gpsSource == .internal ? "Internal" : "RaceBox",
                isConnected: gpsConnected
            )
            
            // OBD status
            StatusIndicator(
                icon: "car.fill",
                title: "OBD2",
                subtitle: obdConnected ? "Connected" : "Disconnected",
                isConnected: obdConnected
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StatusIndicator: View {
    let icon: String
    let title: String
    let subtitle: String
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isConnected ? .green : .red)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentSessionCard: View {
    let session: LapSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.trackName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatDate(session.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Best Lap")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(session.formattedBestLap)
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Laps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(session.lapCount)")
                        .font(.headline)
                }
            }
            
            Text(session.sessionType.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(getSessionTypeColor(session.sessionType).opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .frame(width: 200, height: 140)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func getSessionTypeColor(_ type: SessionType) -> Color {
        switch type {
        case .practice:
            return .blue
        case .qualifying:
            return .orange
        case .race:
            return .red
        case .testing:
            return .purple
        }
    }
}

struct FavoriteTrackCard: View {
    let track: Track
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
            }
            
            Spacer()
            
            if let bestLapTime = track.bestLapTime {
                VStack(alignment: .leading) {
                    Text("Best Lap")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(track.formattedBestLapTime)
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            Text(track.type.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .frame(width: 180, height: 120)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct UserStatsView: View {
    let stats: UserStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.headline)
            
            HStack {
                StatItemView(
                    value: "\(stats.totalSessions)",
                    label: "Sessions",
                    icon: "timer",
                    color: .blue
                )
                
                StatItemView(
                    value: "\(stats.totalLaps)",
                    label: "Laps",
                    icon: "repeat",
                    color: .orange
                )
                
                StatItemView(
                    value: String(format: "%.0f", stats.totalDistance),
                    label: "Kilometers",
                    icon: "speedometer",
                    color: .green
                )
            }
            
            if let fastest = stats.fastestLapTime {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red)
                    
                    Text("Fastest Lap: \(formatTime(fastest)) at \(stats.fastestLapTrack)")
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

struct StatItemView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
                .environmentObject(BluetoothManager())
                .environmentObject(LocationManager())
        }
    }
}
