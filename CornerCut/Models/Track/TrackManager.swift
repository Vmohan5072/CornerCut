//
//  TrackManager.swift
//  RaceBoxLapTimer
//

import Foundation
import Combine

class TrackManager {
    // MARK: - Singleton
    
    static let shared = TrackManager()
    
    // MARK: - Properties
    
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var preloadedTracks: [Track] = []
    
    // MARK: - File Management
    
    private let fileManager = FileManager.default
    private var documentsURL: URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var tracksFileURL: URL {
        return documentsURL.appendingPathComponent("tracks.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        loadTracks()
        loadPreloadedTracks()
    }
    
    // MARK: - Public Methods
    
    func getTracks() -> [Track] {
        return tracks
    }
    
    func getTrack(id: UUID) -> Track? {
        return tracks.first(where: { $0.id == id })
    }
    
    func getAllTracks() -> [Track] {
        // Combine user tracks and preloaded tracks
        return tracks + preloadedTracks
    }
    
    func saveTrack(_ track: Track) {
        // Check if track exists (update) or is new (add)
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index] = track
        } else {
            tracks.append(track)
        }
        
        saveTracks()
    }
    
    func deleteTrack(id: UUID) {
        tracks.removeAll(where: { $0.id == id })
        saveTracks()
    }
    
    func updateTrackUsage(id: UUID, bestLapTime: TimeInterval? = nil) {
        if let index = tracks.firstIndex(where: { $0.id == id }) {
            var updatedTrack = tracks[index]
            updatedTrack.lastUsedDate = Date()
            
            // Update best lap time if provided and better than current
            if let newBestTime = bestLapTime {
                if let currentBest = updatedTrack.bestLapTime {
                    if newBestTime < currentBest {
                        updatedTrack.bestLapTime = newBestTime
                    }
                } else {
                    updatedTrack.bestLapTime = newBestTime
                }
            }
            
            tracks[index] = updatedTrack
            saveTracks()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTracks() {
        guard fileManager.fileExists(atPath: tracksFileURL.path) else {
            tracks = []
            return
        }
        
        do {
            let data = try Data(contentsOf: tracksFileURL)
            tracks = try JSONDecoder().decode([Track].self, from: data)
        } catch {
            print("Error loading tracks: \(error.localizedDescription)")
            tracks = []
        }
    }
    
    private func saveTracks() {
        do {
            let data = try JSONEncoder().encode(tracks)
            try data.write(to: tracksFileURL)
        } catch {
            print("Error saving tracks: \(error.localizedDescription)")
        }
    }
    
    private func loadPreloadedTracks() {
        guard let url = Bundle.main.url(forResource: "PreloadedTracks", withExtension: "json") else {
            preloadedTracks = []
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            preloadedTracks = try JSONDecoder().decode([Track].self, from: data)
        } catch {
            print("Error loading preloaded tracks: \(error.localizedDescription)")
            preloadedTracks = []
        }
    }
}
