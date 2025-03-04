import SwiftUI
import MapKit
import CoreLocation

struct TrackListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedRegion: TrackRegion = .all
    @State private var showingMapView = false
    @State private var selectedTrack: Track?
    
    // Callback when a track is selected
    var onTrackSelected: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search tracks", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top)
            
            // Region filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TrackRegion.allCases, id: \.self) { region in
                        RegionFilterButton(
                            region: region,
                            isSelected: region == selectedRegion
                        ) {
                            selectedRegion = region
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Track list
            List {
                ForEach(filteredTracks) { track in
                    TrackListRow(track: track)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTrack = track
                            showingMapView = true
                        }
                }
            }
            .listStyle(PlainListStyle())
            
            // Create custom track button
            Button {
                // Use the custom track option
                onTrackSelected("Custom Track")
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Custom Track")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("Select Track")
        .sheet(isPresented: $showingMapView) {
            if let track = selectedTrack {
                TrackDetailView(track: track) {
                    onTrackSelected(track.name)
                    dismiss()
                }
            }
        }
    }
    
    // Filtered tracks based on region and search
    private var filteredTracks: [Track] {
        var tracks = sampleTracks
        
        // Filter by region
        if selectedRegion != .all {
            tracks = tracks.filter { $0.region == selectedRegion }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            tracks = tracks.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return tracks
    }
}

// MARK: - Supporting Views

struct RegionFilterButton: View {
    var region: TrackRegion
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(region.rawValue)
                .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(UIColor.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct TrackListRow: View {
    var track: Track
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.headline)
                
                Text(track.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.2f", track.length)) mi")
                    .font(.subheadline)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text("\(track.difficulty)/5")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TrackDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var track: Track
    var onSelect: () -> Void
    
    @State private var region: MKCoordinateRegion
    
    init(track: Track, onSelect: @escaping () -> Void) {
        self.track = track
        self.onSelect = onSelect
        
        // Initialize map region centered on the track with appropriate zoom
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        self._region = State(initialValue: MKCoordinateRegion(
            center: track.coordinates,
            span: span
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Map view
            Map(coordinateRegion: $region, annotationItems: [track]) { track in
                MapMarker(coordinate: track.coordinates, tint: .red)
            }
            .frame(height: 250)
            .edgesIgnoringSafeArea(.top)
            
            // Track details
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(track.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(track.location)
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                HStack {
                    InfoItem(title: "Track Length", value: "\(String(format: "%.2f", track.length)) mi")
                    Spacer()
                    InfoItem(title: "Turns", value: "\(track.turns)")
                    Spacer()
                    InfoItem(title: "Difficulty", value: "\(track.difficulty)/5")
                }
                
                if !track.description.isEmpty {
                    Divider()
                    
                    Text("Description")
                        .font(.headline)
                    
                    Text(track.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onSelect) {
                    Text("Start Session at \(track.name)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

struct InfoItem: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Data Models

enum TrackRegion: String, CaseIterable {
    case all = "All"
    case west = "West Coast"
    case midwest = "Midwest"
    case northeast = "Northeast"
    case southeast = "Southeast"
    case southwest = "Southwest"
}

struct Track: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let region: TrackRegion
    let length: Double // In miles
    let turns: Int
    let difficulty: Int // 1-5 scale
    let coordinates: CLLocationCoordinate2D
    let description: String
}

// Sample track data
let sampleTracks: [Track] = [
    Track(
        name: "Laguna Seca",
        location: "Monterey, CA",
        region: .west,
        length: 2.238,
        turns: 11,
        difficulty: 4,
        coordinates: CLLocationCoordinate2D(latitude: 36.5841, longitude: -121.7532),
        description: "Home to the famous Corkscrew, Laguna Seca is one of America's most iconic racetracks."
    ),
    Track(
        name: "Road America",
        location: "Elkhart Lake, WI",
        region: .midwest,
        length: 4.048,
        turns: 14,
        difficulty: 3,
        coordinates: CLLocationCoordinate2D(latitude: 43.7984, longitude: -87.9943),
        description: "One of the longest and fastest road racing tracks in North America."
    ),
    Track(
        name: "Watkins Glen",
        location: "Watkins Glen, NY",
        region: .northeast,
        length: 3.4,
        turns: 11,
        difficulty: 4,
        coordinates: CLLocationCoordinate2D(latitude: 42.3361, longitude: -76.9274),
        description: "A historic track hosting NASCAR and other major racing events."
    ),
    Track(
        name: "Sonoma Raceway",
        location: "Sonoma, CA",
        region: .west,
        length: 2.52,
        turns: 12,
        difficulty: 3,
        coordinates: CLLocationCoordinate2D(latitude: 38.1613, longitude: -122.4546),
        description: "A challenging road course with elevation changes and technical sections."
    ),
    Track(
        name: "Circuit of the Americas",
        location: "Austin, TX",
        region: .southwest,
        length: 3.426,
        turns: 20,
        difficulty: 5,
        coordinates: CLLocationCoordinate2D(latitude: 30.1346, longitude: -97.6411),
        description: "America's Formula 1 track with challenging elevation changes and technical corners."
    ),
    Track(
        name: "Road Atlanta",
        location: "Braselton, GA",
        region: .southeast,
        length: 2.54,
        turns: 12,
        difficulty: 4,
        coordinates: CLLocationCoordinate2D(latitude: 34.1397, longitude: -83.8162),
        description: "Host of the Petit Le Mans endurance race."
    ),
    Track(
        name: "Virginia International Raceway",
        location: "Alton, VA",
        region: .southeast,
        length: 3.27,
        turns: 17,
        difficulty: 4,
        coordinates: CLLocationCoordinate2D(latitude: 36.5608, longitude: -79.2040),
        description: "One of America's most challenging road courses with multiple configuration options."
    ),
    Track(
        name: "Thunderhill Raceway",
        location: "Willows, CA",
        region: .west,
        length: 3.0,
        turns: 15,
        difficulty: 3,
        coordinates: CLLocationCoordinate2D(latitude: 39.5375, longitude: -122.3377),
        description: "Popular for endurance racing and track days."
    ),
    Track(
        name: "Mid-Ohio",
        location: "Lexington, OH",
        region: .midwest,
        length: 2.4,
        turns: 13,
        difficulty: 3,
        coordinates: CLLocationCoordinate2D(latitude: 40.6895, longitude: -82.6381),
        description: "A technical track with elevation changes and challenging corners."
    ),
    Track(
        name: "Lime Rock Park",
        location: "Lakeville, CT",
        region: .northeast,
        length: 1.5,
        turns: 7,
        difficulty: 2,
        coordinates: CLLocationCoordinate2D(latitude: 41.9279, longitude: -73.3839),
        description: "A short but technical track nestled in the Connecticut hills."
    )
]
