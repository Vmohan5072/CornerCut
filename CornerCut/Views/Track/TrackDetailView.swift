//
//  TrackDetailView.swift
//  RaceBoxLapTimer
//

import SwiftUI
import MapKit

struct TrackDetailView: View {
    let track: Track
    @State private var showingSessionOptions = false
    @State private var region: MKCoordinateRegion
    @Environment(\.presentationMode) var presentationMode
    
    init(track: Track) {
        self.track = track
        _region = State(initialValue: track.getRegion())
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
                    
                    Divider()
                    
                    // Previous sessions on this track
                    Text("Previous Sessions")
                        .font(.headline)
                    
                    // Placeholder for session history
                    // This would be populated with actual session data
                    Text("No previous sessions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
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
                    .cancel()
                ]
            )
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
        // This would navigate to the ActiveSessionView with the selected track and session type
        // For now, we'll just print the info
        print("Starting \(type.rawValue) session on \(track.name)")
        
        // In a real implementation:
        // Navigate to ActiveSessionView with the track and session type
    }
}

struct TrackPointAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
    let isEnd: Bool
}

enum SessionType: String {
    case practice = "Practice"
    case qualifying = "Qualifying"
    case race = "Race"
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
