//
//  TrackDetailView.swift
//  CornerCut
//

import SwiftUI
import MapKit

struct TrackDetailView: View {
    let track: Track
    @State private var showingSessionOptions = false
    @State private var region: MKCoordinateRegion
    @State private var trackSessions: [LapSession] = []
    @Environment(\.presentationMode) var presentationMode
    
    init(track: Track) {
        self.track = track
        _region = State(initialValue: track.getRegion())
        _trackSessions = State(initialValue: SessionManager.shared.getSessionsForTrack(trackId: track.id))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Map with start/finish line
                Map(coordinateRegion: $region, annotationItems: trackAnnotations()) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        if item.isStart {
                            Image(systemName: "flag.checkered.circle.fill")
                                .font(.title)
                                .foregroundColor(.green)
                        } else if item.isEnd {
                            Image(systemName: "flag.checkered.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(height: 250)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Track details
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(track.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text(track.type.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    if !track.location.isEmpty {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(track.location)
                                .font(.subheadline)
                        }
                    }
                    
                    if let trackLength = track.trackLength {
                        HStack {
                            Image(systemName: "ruler.fill")
                                .foregroundColor(.blue)
                            Text("\(String(format: "%.2f", trackLength / 1000)) km")
                                .font(.subheadline)
                        }
                    }
                    
                    if let bestLapTime = track.bestLapTime {
                        HStack {
                            Image(systemName: "stopwatch.fill")
                                .foregroundColor(.green)
                            Text("Best lap: \(track.formattedBestLapTime)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 1)
                .padding(.horizontal)
                
                // Previous sessions on this track
                VStack(alignment: .leading, spacing: 10) {
                    Text("Previous Sessions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if trackSessions.isEmpty {
                        Text("No previous sessions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.horizontal)
                    } else {
                        ForEach(trackSessions) { session in
                            NavigationLink(destination: SessionReviewView(session: session)) {
                                TrackSessionRow(session: session)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(
            trailing: Button(action: {
                showingSessionOptions = true
            }) {
                Text("Start Session")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        )
        .actionSheet(isPresented: $showingSessionOptions) {
            ActionSheet(
                title: Text("Start Session"),
                message: Text("Select a session type for \(track.name)"),
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
        .onAppear {
            // Refresh sessions when view appears
            trackSessions = SessionManager.shared.getSessionsForTrack(trackId: track.id)
        }
    }
    
    // Generate annotations for the map
    private func trackAnnotations() -> [TrackPointAnnotation] {
        var annotations = [TrackPointAnnotation]()
        
        // Start point
        annotations.append(
            TrackPointAnnotation(
                id: "start",
                coordinate: track.startFinishLine.point.coordinate,
                isStart: true,
                isEnd: false
            )
        )
        
        // End point for point-to-point tracks
        if track.type == .pointToPoint, let endPoint = track.startFinishLine.endPoint {
            annotations.append(
                TrackPointAnnotation(
                    id: "end",
                    coordinate: endPoint.coordinate,
                    isStart: false,
                    isEnd: true
                )
            )
        }
        
        return annotations
    }
    
    private func startSession(type: SessionType) {
        // Create a view model for the session
        let sessionViewModel = SessionViewModel()
        
        // Navigate to the active session view
        let activeSessionView = ActiveSessionView(viewModel: sessionViewModel)
        
        // Start the session with the selected track and type
        sessionViewModel.startSession(track: track, sessionType: type)
        
        // In a real implementation, we would navigate to the active session view
        // This would require a coordinator pattern or another navigation approach
        // For now, we'll simply print the info
        print("Starting \(type.rawValue) session on \(track.name)")
    }
}

struct TrackPointAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
    let isEnd: Bool
}

struct TrackSessionRow: View {
    let session: LapSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.sessionType.rawValue)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(getSessionTypeColor(session.sessionType).opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(formatDate(session.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(session.lapCount) laps")
                    .font(.subheadline)
                
                Spacer()
                
                if let bestLap = session.bestLap {
                    Text("Best: \(bestLap.formattedLapTime)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.green)
                } else {
                    Text("No valid laps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
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

struct TrackDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TrackDetailView(
            track: Track(
                name: "Laguna Seca",
                type: .circuit,
                startFinishLine: StartFinishLine(
                    point: GeoPoint(latitude: 36.5847, longitude: -121.7520)
                ),
                location: "Monterey, CA",
                trackLength: 3602,
                bestLapTime: 90.456
            )
        )
    }
}
