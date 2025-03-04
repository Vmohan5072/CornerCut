import SwiftUI
import SwiftData
import MapKit
import Charts

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: Session
    
    @State private var selectedLap: Lap?
    @State private var showingVideoOverlay = false
    @State private var showingDeleteConfirmation = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var trackCoordinates: [CLLocationCoordinate2D] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Session Header Card
                SessionHeaderCard(session: session)
                    .padding(.horizontal)
                
                // Track Map
                if !trackCoordinates.isEmpty {
                    TrackMapView(
                        region: $mapRegion,
                        coordinates: trackCoordinates,
                        selectedLap: $selectedLap
                    )
                    .frame(height: 250)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Lap Times Card
                LapTimesCard(
                    session: session,
                    selectedLap: $selectedLap
                )
                .padding(.horizontal)
                
                // Performance Charts
                if let lap = selectedLap ?? session.laps.first {
                    PerformanceChartsCard(lap: lap)
                        .padding(.horizontal)
                }
                
                // Video Overlay Button
                if showVideoOverlayButton() {
                    Button {
                        showingVideoOverlay = true
                    } label: {
                        HStack {
                            Image(systemName: "film")
                            Text(session.videoURL != nil ? "Edit Video Overlay" : "Import & Overlay Video")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // Delete Button
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Session")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(sessionTitle())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedLap = session.laps.first
            loadTrackCoordinates()
        }
        .confirmationDialog(
            "Delete Session",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSession()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showingVideoOverlay) {
            NavigationView {
                VideoOverlayView(session: session)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showingVideoOverlay = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func sessionTitle() -> String {
        if let customName = session.customName, !customName.isEmpty {
            return customName
        } else {
            return session.trackName
        }
    }
    
    private func showVideoOverlayButton() -> Bool {
        // Only show video button if we have telemetry data
        return !session.laps.isEmpty && session.laps.flatMap { $0.telemetryData }.count > 0
    }
    
    private func loadTrackCoordinates() {
        // Extract all GPS coordinates from telemetry data
        let coordinates = session.laps.flatMap { lap in
            lap.telemetryData.compactMap { data in
                CLLocationCoordinate2D(latitude: data.latitude, longitude: data.longitude)
            }
        }
        
        // Only update if we have coordinates
        if !coordinates.isEmpty {
            trackCoordinates = coordinates
            
            // Calculate center and span for the map
            if let minLat = coordinates.map({ $0.latitude }).min(),
               let maxLat = coordinates.map({ $0.latitude }).max(),
               let minLon = coordinates.map({ $0.longitude }).min(),
               let maxLon = coordinates.map({ $0.longitude }).max() {
                
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                )
                
                // Add some padding to the span
                let latDelta = (maxLat - minLat) * 1.2
                let lonDelta = (maxLon - minLon) * 1.2
                
                mapRegion = MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(
                        latitudeDelta: max(0.001, latDelta),
                        longitudeDelta: max(0.001, lonDelta)
                    )
                )
            }
        }
    }
    
    private func deleteSession() {
        modelContext.delete(session)
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct SessionHeaderCard: View {
    let session: Session
    
    var body: some View {
        VStack(spacing: 16) {
            // Session date and type
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date, style: .date)
                        .font(.headline)
                    
                    Text(session.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                SessionTypeTag(session: session)
            }
            
            Divider()
            
            // Session stats
            HStack(spacing: 20) {
                StatItem(
                    value: "\(session.laps.count)",
                    label: "Laps"
                )
                
                StatItem(
                    value: formatTime(bestLapTime()),
                    label: "Best Lap"
                )
                
                StatItem(
                    value: formatDuration(totalDuration()),
                    label: "Duration"
                )
            }
            
            // Device info
            if session.usingExternalGPS {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                    
                    Text("RaceBox GPS")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func bestLapTime() -> Double {
        guard !session.laps.isEmpty else { return 0 }
        return session.laps.min(by: { $0.lapTime < $1.lapTime })?.lapTime ?? 0
    }
    
    private func totalDuration() -> TimeInterval {
        return session.laps.reduce(0) { $0 + $1.lapTime }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds == 0 { return "--:--" }
        
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%01d:%02d.%03d", minutes, secs, milliseconds)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "--"
    }
}

struct SessionTypeTag: View {
    let session: Session
    
    var body: some View {
        Text(typeLabel())
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(typeColor())
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private func typeLabel() -> String {
        if session.trackName.starts(with: "Custom:") {
            return "Custom"
        } else {
            return "Circuit"
        }
    }
    
    private func typeColor() -> Color {
        if session.trackName.starts(with: "Custom:") {
            return .green
        } else {
            return .blue
        }
    }
}

struct StatItem: View {
    var value: String
    var label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TrackMapView: View {
    @Binding var region: MKCoordinateRegion
    let coordinates: [CLLocationCoordinate2D]
    @Binding var selectedLap: Lap?
    
    var body: some View {
        Map(coordinateRegion: $region) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color.blue, lineWidth: 3)
            
            // Start point marker
            if let start = coordinates.first {
                Marker("Start", coordinate: start)
                    .tint(.green)
            }
            
            // End point marker (if different from start)
            if let end = coordinates.last, end.latitude != coordinates.first?.latitude || end.longitude != coordinates.first?.longitude {
                Marker("Finish", coordinate: end)
                    .tint(.red)
            }
        }
    }
}

struct LapTimesCard: View {
    let session: Session
    @Binding var selectedLap: Lap?
    
    @State private var sortOrder: SortOrder = .ascending
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Lap Times")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    sortOrder = sortOrder == .ascending ? .descending : .ascending
                } label: {
                    Label(
                        sortOrder == .ascending ? "Oldest First" : "Newest First",
                        systemImage: sortOrder == .ascending ? "arrow.up" : "arrow.down"
                    )
                    .font(.caption)
                }
            }
            
            if session.laps.isEmpty {
                Text("No lap data recorded")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // Lap times list
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sortedLaps()) { lap in
                            LapTimeItem(
                                lap: lap,
                                isSelected: selectedLap?.id == lap.id,
                                isBest: lap.lapTime == bestLapTime()
                            )
                            .onTapGesture {
                                selectedLap = lap
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func sortedLaps() -> [Lap] {
        switch sortOrder {
        case .ascending:
            return session.laps.sorted { $0.lapNumber < $1.lapNumber }
        case .descending:
            return session.laps.sorted { $0.lapNumber > $1.lapNumber }
        }
    }
    
    private func bestLapTime() -> TimeInterval {
        return session.laps.min(by: { $0.lapTime < $1.lapTime })?.lapTime ?? 0
    }
}

struct LapTimeItem: View {
    let lap: Lap
    let isSelected: Bool
    let isBest: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Lap \(lap.lapNumber)")
                .font(.caption)
                .foregroundColor(isSelected ? .white : .gray)
            
            Text(formatTime(lap.lapTime))
                .font(.headline)
                .foregroundColor(isSelected ? .white : (isBest ? .green : .primary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
        )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%01d:%02d.%03d", minutes, secs, milliseconds)
    }
}

struct PerformanceChartsCard: View {
    let lap: Lap
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Performance Data - Lap \(lap.lapNumber)")
                .font(.headline)
            
            if lap.telemetryData.isEmpty {
                Text("No telemetry data available for this lap")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // Speed Chart
                SpeedChart(telemetryData: lap.telemetryData)
                    .frame(height: 200)
                
                Divider()
                
                // RPM & Throttle Chart
                RPMThrottleChart(telemetryData: lap.telemetryData)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct SpeedChart: View {
    let telemetryData: [TelemetryData]
    
    var speedData: [(Date, Double)] {
        telemetryData.map { ($0.timestamp, $0.speed * 2.23694) } // Convert m/s to mph
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speed (MPH)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart {
                ForEach(speedData, id: \.0) { item in
                    LineMark(
                        x: .value("Time", item.0),
                        y: .value("Speed", item.1)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.minute().second())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
        }
    }
}

struct RPMThrottleChart: View {
    let telemetryData: [TelemetryData]
    
    var rpmData: [(Date, Double)] {
        telemetryData.map { ($0.timestamp, $0.rpm) }
    }
    
    var throttleData: [(Date, Double)] {
        telemetryData.map { ($0.timestamp, $0.throttle) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RPM & Throttle")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart {
                ForEach(rpmData, id: \.0) { item in
                    LineMark(
                        x: .value("Time", item.0),
                        y: .value("RPM", item.1)
                    )
                    .foregroundStyle(Color.red)
                    .interpolationMethod(.catmullRom)
                }
                .accessibilityLabel("RPM")
                
                ForEach(throttleData, id: \.0) { item in
                    LineMark(
                        x: .value("Time", item.0),
                        y: .value("Throttle", item.1 * (8000/100)) // Scale to match RPM chart
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.catmullRom)
                }
                .accessibilityLabel("Throttle")
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.minute().second())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        let value = $0.as(CGFloat.self) ?? 0
                        // Left axis shows RPM
                        Text("\(Int(value))")
                    }
                }
                AxisMarks(position: .trailing) { _ in
                    AxisValueLabel {
                        let value = $0.as(CGFloat.self) ?? 0
                        // Right axis shows throttle percentage
                        if value == 0 || value == 8000 { // Show only at the extremes
                            Text("\(Int(value * (100/8000)))%")
                        }
                    }
                }
            }
            
            // Legend
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("RPM")
                    .font(.caption)
                
                Spacer()
                    .frame(width: 20)
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Throttle")
                    .font(.caption)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Helper Enums

enum SortOrder {
    case ascending
    case descending
}
