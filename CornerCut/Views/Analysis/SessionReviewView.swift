//
//  SessionReviewView.swift
//  CornerCut
//

import SwiftUI

struct SessionReviewView: View {
    let session: LapSession
    @StateObject private var viewModel = AnalysisViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session Info Card
                SessionInfoCard(session: session)
                    .padding(.horizontal)
                
                // Lap Times and Comparison
                LapTimesView(session: session, viewModel: viewModel)
                    .padding(.horizontal)
                
                // Session Statistics
                SessionStatsView(session: session)
                    .padding(.horizontal)
                
                // Lap Selection for Detailed Analysis
                VStack(alignment: .leading, spacing: 10) {
                    Text("Lap Analysis")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    NavigationLink(destination:
                        LapAnalysisView(viewModel: viewModel)
                            .onAppear {
                                viewModel.loadSession(session)
                            }
                    ) {
                        HStack {
                            Text("View Detailed Lap Analysis")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
                
                // Consistency Analysis
                ConsistencyAnalysisView(session: session)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            .padding(.vertical)
        }
        .navigationTitle("Session Review")
    }
}

struct SessionInfoCard: View {
    let session: LapSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.trackName)
                        .font(.headline)
                    
                    Text(session.sessionType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(session.startTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(session.formattedDuration)
                        .font(.body)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Laps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(session.lapCount)")
                        .font(.body)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Best Lap")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(session.formattedBestLap)
                        .font(.body)
                        .foregroundColor(.green)
                }
            }
            
            if let weather = WeatherCondition(rawValue: session.weather.rawValue) {
                HStack {
                    Image(systemName: weather.icon)
                        .foregroundColor(.blue)
                    Text(weather.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct LapTimesView: View {
    let session: LapSession
    @ObservedObject var viewModel: AnalysisViewModel
    @State private var selectedLapId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lap Times")
                .font(.headline)
            
            // Best lap as reference
            if let bestLap = session.bestLap {
                HStack {
                    Text("Lap \(bestLap.lapNumber)")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(bestLap.formattedLapTime)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Text("BEST")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // All other laps
            ForEach(session.laps.filter { $0.id != session.bestLap?.id }.sorted(by: { $0.lapNumber < $1.lapNumber })) { lap in
                Button(action: {
                    selectedLapId = lap.id
                    viewModel.loadLap(lap)
                }) {
                    HStack {
                        Text("Lap \(lap.lapNumber)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if lap.isValid {
                            Text(lap.formattedLapTime)
                                .font(.system(.body, design: .monospaced))
                            
                            if let bestLap = session.bestLap {
                                let delta = lap.lapTime - bestLap.lapTime
                                Text(formatDelta(delta))
                                    .font(.caption)
                                    .foregroundColor(delta > 0 ? .red : .green)
                            }
                        } else {
                            Text("Invalid")
                                .font(.caption)
                                .foregroundColor(.red)
                                .italic()
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(selectedLapId == lap.id ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDelta(_ delta: TimeInterval) -> String {
        let sign = delta > 0 ? "+" : "-"
        let absDelta = abs(delta)
        
        let seconds = Int(absDelta)
        let milliseconds = Int((absDelta.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%@%d.%03d", sign, seconds, milliseconds)
    }
}

struct SessionStatsView: View {
    let session: LapSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Statistics")
                .font(.headline)
            
            // Calculate statistics
            Group {
                if let avgLapTime = session.getAverageLapTime() {
                    StatRow(title: "Average Lap Time", value: formatTime(avgLapTime))
                }
                
                if let consistency = session.getLapConsistency() {
                    StatRow(title: "Consistency Score", value: String(format: "%.1f%%", consistency),
                           description: getConsistencyDescription(consistency))
                }
                
                StatRow(title: "Valid Laps", value: "\(session.laps.filter { $0.isValid }.count)/\(session.laps.count)")
                
                if let bestLap = session.bestLap {
                    if let maxSpeed = bestLap.maxSpeed {
                        if SettingsManager.shared.unitSystem == .imperial {
                            StatRow(title: "Top Speed", value: String(format: "%.1f mph", maxSpeed * 2.23694))
                        } else {
                            StatRow(title: "Top Speed", value: String(format: "%.1f km/h", maxSpeed * 3.6))
                        }
                    }
                }
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
    
    private func getConsistencyDescription(_ score: Double) -> String {
        if score < 1.0 {
            return "Excellent"
        } else if score < 2.0 {
            return "Very Good"
        } else if score < 3.0 {
            return "Good"
        } else if score < 4.0 {
            return "Fair"
        } else {
            return "Needs Improvement"
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var description: String? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConsistencyAnalysisView: View {
    let session: LapSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lap Time Consistency")
                .font(.headline)
            
            // Lap time visualization
            if session.lapCount > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Line for average time
                        if let avgTime = session.getAverageLapTime() {
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: geometry.size.width, height: 1)
                                .offset(y: getYPosition(for: avgTime, in: geometry))
                            
                            // Label for average
                            Text("Avg")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .offset(y: getYPosition(for: avgTime, in: geometry))
                        }
                        
                        // Bar chart for lap times
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(session.laps.filter { $0.isValid }.sorted(by: { $0.lapNumber < $1.lapNumber })) { lap in
                                VStack {
                                    Rectangle()
                                        .fill(getBarColor(for: lap))
                                        .frame(height: getBarHeight(for: lap, in: geometry))
                                    
                                    Text("\(lap.lapNumber)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: getBarWidth(in: geometry))
                            }
                        }
                        .frame(height: geometry.size.height)
                        
                        // Best lap line
                        if let bestLap = session.bestLap {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width, height: 1)
                                .offset(y: getYPosition(for: bestLap.lapTime, in: geometry))
                            
                            // Label for best
                            Text("Best")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .offset(y: getYPosition(for: bestLap.lapTime, in: geometry) - 12)
                        }
                    }
                }
                .frame(height: 150)
                .padding(.top, 10)
            } else {
                Text("No lap data available for consistency analysis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func getBarColor(for lap: LapData) -> Color {
        guard let bestLap = session.bestLap else { return Color.blue }
        
        // Color based on delta to best lap
        let delta = lap.lapTime - bestLap.lapTime
        
        if delta < 0 {
            return .green
        } else if delta < 1.0 {
            return .blue
        } else if delta < 3.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getBarWidth(in geometry: GeometryProxy) -> CGFloat {
        let lapCount = session.laps.filter { $0.isValid }.count
        if lapCount > 0 {
            return max(10, geometry.size.width / CGFloat(lapCount) - 4)
        }
        return 10
    }
    
    private func getBarHeight(for lap: LapData, in geometry: GeometryProxy) -> CGFloat {
        guard let bestLap = session.bestLap else { return 0 }
        
        // Find worst lap to scale the chart
        let worstLapTime = session.laps.filter { $0.isValid }.map { $0.lapTime }.max() ?? bestLap.lapTime
        let range = worstLapTime - bestLap.lapTime
        
        // Scale to fit in the available height
        // Inverse the height calculation (longer lap = shorter bar)
        let normalizedHeight = 1.0 - ((lap.lapTime - bestLap.lapTime) / (range + 0.001))
        return geometry.size.height * 0.8 * CGFloat(normalizedHeight)
    }
    
    private func getYPosition(for time: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
        guard let bestLap = session.bestLap else { return 0 }
        
        // Find worst lap to scale the chart
        let worstLapTime = session.laps.filter { $0.isValid }.map { $0.lapTime }.max() ?? bestLap.lapTime
        let range = worstLapTime - bestLap.lapTime
        
        // Calculate vertical position (inverted)
        let normalizedPosition = ((time - bestLap.lapTime) / (range + 0.001))
        return geometry.size.height * 0.8 * CGFloat(normalizedPosition)
    }
}

struct SessionReviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SessionReviewView(session: LapSession(
                trackId: UUID(),
                trackName: "Laguna Seca",
                sessionType: .practice,
                laps: [
                    LapData(lapNumber: 1, lapTime: 90.5),
                    LapData(lapNumber: 2, lapTime: 89.2),
                    LapData(lapNumber: 3, lapTime: 88.7),
                    LapData(lapNumber: 4, lapTime: 91.1)
                ]
            ))
        }
    }
}
