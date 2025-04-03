import Foundation
import Combine

class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var recentSessions: [LapSession] = []
    @Published var favoriteTracks: [Track] = []
    @Published var stats: UserStats = UserStats()
    @Published var connectionStatus: ConnectionStatus = ConnectionStatus()
    @Published var isLoading: Bool = false
    
    // MARK: - Dependencies
    
    private let sessionManager = SessionManager.shared
    private let trackManager = TrackManager.shared
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadData()
    }
    
    // MARK: - Public Methods
    
    func loadData() {
        isLoading = true
        
        // Load recent sessions
        recentSessions = sessionManager.getAllSessions().prefix(5).map { $0 }
        
        // Load favorite tracks
        loadFavoriteTracks()
        
        // Load user stats
        calculateUserStats()
        
        isLoading = false
    }
    
    func refreshData() {
        loadData()
    }
    
    // MARK: - Private Methods
    
    private func loadFavoriteTracks() {
        // Get all tracks
        let allTracks = trackManager.getAllTracks()
        
        // Sort by last used date and take top 3
        favoriteTracks = allTracks
            .filter { $0.lastUsedDate != nil }
            .sorted(by: { $0.lastUsedDate! > $1.lastUsedDate! })
            .prefix(3)
            .map { $0 }
        
        // If we have fewer than 3 tracks with usage data, just add the most recent tracks
        if favoriteTracks.count < 3 {
            let remainingTracks = allTracks
                .filter { !favoriteTracks.contains($0) }
                .sorted(by: { $0.createdDate > $1.createdDate })
                .prefix(3 - favoriteTracks.count)
            
            favoriteTracks.append(contentsOf: remainingTracks)
        }
    }
    
    private func calculateUserStats() {
        let allSessions = sessionManager.getAllSessions()
        
        var stats = UserStats()
        stats.totalSessions = allSessions.count
        
        // Calculate total laps
        stats.totalLaps = allSessions.reduce(0) { $0 + $1.lapCount }
        
        // Find fastest lap
        if let fastestSession = allSessions.compactMap({ $0.bestLap }).min(by: { $0.lapTime < $1.lapTime }) {
            stats.fastestLapTime = fastestSession.lapTime
            stats.fastestLapTrack = allSessions.first(where: { $0.laps.contains(where: { $0.id == fastestSession.id }) })?.trackName ?? ""
        }
        
        // Calculate total distance (if available)
        // In a real implementation, this would use actual telemetry data
        // For now, let's just estimate based on track lengths and lap counts
        var totalDistance = 0.0
        for session in allSessions {
            if let track = trackManager.getTrack(id: session.trackId), let trackLength = track.trackLength {
                totalDistance += Double(session.lapCount) * (trackLength / 1000.0) // Convert to km
            }
        }
        stats.totalDistance = totalDistance
        
        self.stats = stats
    }
}

// MARK: - Data Models

struct UserStats {
    var totalSessions: Int = 0
    var totalLaps: Int = 0
    var totalDistance: Double = 0  // In kilometers
    var fastestLapTime: TimeInterval?
    var fastestLapTrack: String = ""
}

struct ConnectionStatus {
    var isGPSConnected: Bool = false
    var isOBDConnected: Bool = false
    var gpsSource: GPSSource = .internal
}
