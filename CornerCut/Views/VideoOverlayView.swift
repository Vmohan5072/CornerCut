import SwiftUI
import AVKit
import Combine
import PhotosUI

struct VideoOverlayView: View {
    // MARK: - Environment & State
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    // Session data being used for the overlay
    let session: Session
    
    // MARK: - State Properties
    @StateObject private var viewModel = VideoOverlayViewModel()
    @State private var currentVideo: AVPlayer?
    @State private var isPlaying = false
    @State private var showingVideoImporter = false
    @State private var timeOffset: Double = 0.0
    @State private var showingExportOptions = false
    @State private var exportProgress: Float = 0.0
    @State private var isExporting = false
    @State private var showingExportSuccess = false
    @State private var exportedURL: URL?
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Video preview area with overlay
            ZStack {
                if let player = currentVideo {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            TelemetryOverlayView(
                                speed: viewModel.currentSpeed,
                                rpm: viewModel.currentRPM,
                                throttle: viewModel.currentThrottle,
                                gear: viewModel.currentGear
                            )
                            .allowsHitTesting(false)
                        )
                } else {
                    Rectangle()
                        .fill(Color(UIColor.systemGray6))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack {
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                
                                Text("Import a video to get started")
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                            }
                        )
                }
            }
            .padding()
            
            Divider()
            
            // Timeline and playback controls
            VStack(spacing: 16) {
                // Playback slider
                if currentVideo != nil {
                    HStack {
                        Text(formatTimeCode(viewModel.currentVideoTime))
                            .font(.caption)
                            .monospacedDigit()
                        
                        Slider(value: $viewModel.currentVideoTime, in: 0...viewModel.videoDuration) { editing in
                            if !editing {
                                seekVideo(to: viewModel.currentVideoTime)
                            }
                        }
                        .accentColor(Color.blue)
                        
                        Text(formatTimeCode(viewModel.videoDuration))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding(.horizontal)
                    
                    // Playback controls
                    HStack(spacing: 24) {
                        Spacer()
                        
                        Button {
                            seekVideo(by: -10)
                        } label: {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                        }
                        
                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                        }
                        
                        Button {
                            seekVideo(by: 10)
                        } label: {
                            Image(systemName: "goforward.10")
                                .font(.title2)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                
                Divider()
                
                // Timing offset adjustment
                VStack(spacing: 8) {
                    Text("Timing Offset: \(timeOffset, specifier: "%.1f")s")
                        .font(.headline)
                    
                    HStack {
                        Text("-5.0s")
                            .font(.caption)
                        
                        Slider(value: $timeOffset, in: -5.0...5.0, step: 0.1)
                            .accentColor(Color.green)
                            .onChange(of: timeOffset) { newValue in
                                viewModel.updateTimingOffset(newValue)
                            }
                        
                        Text("+5.0s")
                            .font(.caption)
                    }
                    
                    Text("Adjust to synchronize telemetry data with video")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        showingVideoImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Video")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button {
                        showingExportOptions = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(currentVideo != nil ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(currentVideo == nil)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("Video Overlay")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .sheet(isPresented: $showingVideoImporter) {
            VideoPickerView { url in
                if let url = url {
                    loadVideo(from: url)
                }
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsSheet(
                onExport: { quality, includeOverlay in
                    exportVideo(quality: quality, includeOverlay: includeOverlay)
                }
            )
        }
        .alert("Export Complete", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) { }
            if let url = exportedURL {
                Button("Share") {
                    shareVideo(url: url)
                }
            }
        } message: {
            Text("Your video has been successfully exported with telemetry overlay.")
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView(value: exportProgress, total: 1.0)
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("Exporting Video...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 16)
                        
                        Text("\(Int(exportProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                }
            }
        }
        .onAppear {
            loadSessionData()
            
            // Check if session already has a video URL
            if let existingVideo = session.videoURL {
                loadVideo(from: existingVideo)
            }
        }
        .onDisappear {
            currentVideo?.pause()
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSessionData() {
        viewModel.loadSessionData(session)
    }
    
    private func loadVideo(from url: URL) {
        // Create AVPlayer for the video
        let player = AVPlayer(url: url)
        currentVideo = player
        
        // Get video duration
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                viewModel.videoDuration = CMTimeGetSeconds(duration)
                
                // Set up time observation
                setupTimeObserver(for: player)
            } catch {
                print("Error loading video duration: \(error)")
            }
        }
    }
    
    private func setupTimeObserver(for player: AVPlayer) {
        // Add time observer to update current playback time
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let seconds = CMTimeGetSeconds(time)
            viewModel.currentVideoTime = seconds
            viewModel.updateTelemetryForTime(seconds)
        }
        
        // Observe when playback ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
        }
    }
    
    private func togglePlayback() {
        guard let player = currentVideo else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        
        isPlaying.toggle()
    }
    
    private func seekVideo(to time: Double) {
        guard let player = currentVideo else { return }
        
        let targetTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func seekVideo(by seconds: Double) {
        guard let player = currentVideo else { return }
        
        let currentTime = player.currentTime().seconds
        let newTime = max(0, min(currentTime + seconds, viewModel.videoDuration))
        seekVideo(to: newTime)
    }
    
    private func formatTimeCode(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func exportVideo(quality: ExportQuality, includeOverlay: Bool) {
        guard let videoURL = session.videoURL else { return }
        
        isExporting = true
        
        // For demo purposes, we'll simulate export progress
        var progress: Float = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            progress += 0.05
            if progress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Simulate successful export
                    isExporting = false
                    exportProgress = 0.0
                    exportedURL = videoURL // In a real implementation, this would be the new URL
                    showingExportSuccess = true
                }
            }
            exportProgress = progress
        }
        
        // In a real implementation, you would:
        // 1. Create an AVMutableComposition
        // 2. Add the video track
        // 3. Set up AVVideoComposition for the overlay
        // 4. Configure export settings based on quality
        // 5. Create an AVAssetExportSession
        // 6. Export to a temporary file
    }
    
    private func shareVideo(url: URL) {
        // Create activity view controller for sharing
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Present the view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - View Model

class VideoOverlayViewModel: ObservableObject {
    @Published var currentVideoTime: Double = 0.0
    @Published var videoDuration: Double = 0.0
    
    @Published var currentSpeed: Double = 0.0
    @Published var currentRPM: Double = 0.0
    @Published var currentThrottle: Double = 0.0
    @Published var currentGear: Int = 1
    @Published var currentLapTime: String = "00:00.000"
    @Published var bestLapTime: String = "00:00.000"
    
    private var timingOffset: Double = 0.0
    private var telemetryData: [TelemetryData] = []
    private var lapData: [Lap] = []
    
    func loadSessionData(_ session: Session) {
        // Flatten all telemetry data from all laps
        telemetryData = session.laps.flatMap { $0.telemetryData }
        
        // Sort by timestamp
        telemetryData.sort { $0.timestamp < $1.timestamp }
        
        // Get lap data
        lapData = session.laps
        
        // Find best lap time
        if let bestLap = lapData.min(by: { $0.lapTime < $1.lapTime }) {
            bestLapTime = formatLapTime(bestLap.lapTime)
        }
    }
    
    func updateTimingOffset(_ offset: Double) {
        timingOffset = offset
        updateTelemetryForTime(currentVideoTime)
    }
    
    func updateTelemetryForTime(_ videoTime: Double) {
        // Adjust time with offset
        let adjustedTime = videoTime + timingOffset
        
        // Find session start time (first telemetry timestamp)
        guard let sessionStart = telemetryData.first?.timestamp else { return }
        
        // Calculate target timestamp
        let targetTimestamp = sessionStart.addingTimeInterval(adjustedTime)
        
        // Find closest telemetry data point
        let closestDataPoint = findClosestTelemetryData(to: targetTimestamp)
        
        // Update telemetry values
        if let dataPoint = closestDataPoint {
            currentSpeed = dataPoint.speed * 2.23694 // Convert m/s to mph
            currentRPM = dataPoint.rpm
            currentThrottle = dataPoint.throttle
            
            // Calculate gear based on RPM and speed (simplified)
            currentGear = calculateGear(rpm: dataPoint.rpm, speed: dataPoint.speed)
        }
        
        // Find current lap
        updateLapTimeForTimestamp(targetTimestamp)
    }
    
    private func findClosestTelemetryData(to timestamp: Date) -> TelemetryData? {
        guard !telemetryData.isEmpty else { return nil }
        
        return telemetryData.min { data1, data2 in
            abs(data1.timestamp.timeIntervalSince(timestamp)) < abs(data2.timestamp.timeIntervalSince(timestamp))
        }
    }
    
    private func updateLapTimeForTimestamp(_ timestamp: Date) {
        guard !lapData.isEmpty else { return }
        
        // Find which lap contains this timestamp
        for lap in lapData {
            if let firstDataPoint = lap.telemetryData.first?.timestamp,
               let lastDataPoint = lap.telemetryData.last?.timestamp {
                
                if timestamp >= firstDataPoint && timestamp <= lastDataPoint {
                    // We're in this lap
                    let lapElapsed = timestamp.timeIntervalSince(firstDataPoint)
                    currentLapTime = formatLapTime(lapElapsed)
                    return
                }
            }
        }
        
        // If not found, default to the first lap's start
        if let firstLapStart = lapData.first?.telemetryData.first?.timestamp {
            let timeSinceStart = timestamp.timeIntervalSince(firstLapStart)
            if timeSinceStart > 0 {
                currentLapTime = formatLapTime(timeSinceStart)
            } else {
                currentLapTime = "00:00.000"
            }
        }
    }
    
    private func formatLapTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, secs, milliseconds)
    }
    
    private func calculateGear(rpm: Double, speed: Double) -> Int {
        // Simplified gear calculation
        // In a real app, this would use vehicle-specific gear ratios
        
        if speed < 1.0 {
            return 1 // Stationary or very slow
        }
        
        // Simple algorithm based on RPM and speed
        let rpmPerSpeed = rpm / speed
        
        if rpmPerSpeed > 500 {
            return 1
        } else if rpmPerSpeed > 300 {
            return 2
        } else if rpmPerSpeed > 200 {
            return 3
        } else if rpmPerSpeed > 150 {
            return 4
        } else if rpmPerSpeed > 120 {
            return 5
        } else {
            return 6
        }
    }
}

// MARK: - Supporting Views

struct TelemetryOverlayView: View {
    var speed: Double
    var rpm: Double
    var throttle: Double
    var gear: Int
    
    private let maxSpeed: Double = 160
    private let maxRPM: Double = 8000
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
            
            VStack {
                Spacer()
                
                // Bottom row: Gauges
                HStack {
                    // Speedometer
                    VideoGaugeView(
                        value: speed,
                        maxValue: maxSpeed,
                        title: "MPH",
                        color: Color.blue
                    )
                    
                    Spacer()
                    
                    // Throttle percentage
                    ThrottleBarView(value: throttle)
                    
                    Spacer()
                    
                    // RPM gauge
                    VideoGaugeView(
                        value: rpm,
                        maxValue: maxRPM,
                        title: "RPM",
                        color: Color.red
                    )
                    
                    Spacer()
                    
                    // Gear indicator
                    GearIndicatorView(gear: gear)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// Renamed to avoid conflict with existing GaugeView
struct VideoGaugeView: View {
    var value: Double
    var maxValue: Double
    var title: String
    var color: Color
    
    var percentage: Double {
        min(1.0, max(0.0, value / maxValue))
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 8)
                .frame(width: 100, height: 100)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(percentage))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
            
            // Value text
            VStack(spacing: 2) {
                Text("\(Int(value))")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct ThrottleBarView: View {
    var value: Double
    
    var percentage: Double {
        min(1.0, max(0.0, value / 100.0))
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("THROTTLE")
                .font(.caption)
                .foregroundColor(.gray)
            
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 120, height: 20)
                    .cornerRadius(4)
                
                // Progress
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 120 * CGFloat(percentage), height: 20)
                    .cornerRadius(4)
            }
            
            Text("\(Int(value))%")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

struct GearIndicatorView: View {
    var gear: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(Color.orange, lineWidth: 3)
                )
            
            VStack(spacing: 0) {
                Text("GEAR")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                Text("\(gear)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Video Picker

struct VideoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onVideoSelected: (URL?) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select a video source")
                    .font(.headline)
                    .padding(.top)
                
                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Choose from Photo Library")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .onChange(of: selectedItem) { newItem in
                    if let newItem = newItem {
                        loadTransferable(from: newItem)
                    }
                }
                
                Button {
                    // This would use document picker in a real implementation
                    dismiss()
                    onVideoSelected(nil)
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("Choose from Files")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Import Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onVideoSelected(nil)
                    }
                }
            }
        }
    }
    
    private func loadTransferable(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Save the video data to a temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("video_\(Date().timeIntervalSince1970).mov")
                do {
                    try data.write(to: tempURL)
                    dismiss()
                    onVideoSelected(tempURL)
                } catch {
                    print("Error saving video: \(error)")
                }
            } else {
                print("Failed to load video data")
                dismiss()
                onVideoSelected(nil)
            }
        }
    }
}

// MARK: - Export Options

enum ExportQuality: String, CaseIterable, Identifiable {
    case low = "Low (540p)"
    case medium = "Medium (720p)"
    case high = "High (1080p)"
    
    var id: String { self.rawValue }
}

struct ExportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuality: ExportQuality = .medium
    @State private var includeOverlay = true
    
    var onExport: (ExportQuality, Bool) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Video Quality")) {
                    Picker("Quality", selection: $selectedQuality) {
                        ForEach(ExportQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Overlay Options")) {
                    Toggle("Include Telemetry Overlay", isOn: $includeOverlay)
                }
                
                Section {
                    Button {
                        dismiss()
                        onExport(selectedQuality, includeOverlay)
                    } label: {
                        Text("Export Video")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Export Options")
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
}

// MARK: - Preview

#Preview {
    // Create a sample Session and TelemetryData for preview
    let sampleSession = Session(
        trackName: "Sample Track",
        usingExternalGPS: true,
        customName: "Sample Session",
        date: Date()
    )
    
    return NavigationView {
        VideoOverlayView(session: sampleSession)
    }
}
