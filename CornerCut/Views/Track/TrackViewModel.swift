//
//  TrackViewModel.swift
//  RaceBoxLapTimer
//

import Foundation
import Combine
import MapKit
import CoreLocation

class TrackViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var tracks: [Track] = []
    @Published var filteredTracks: [Track] = []
    @Published var selectedTrackType: TrackType = .circuit
    @Published var searchText: String = ""
    
    @Published var selectedTrack: Track?
    @Published var isCreatingTrack = false
    
    // Track creation properties
    @Published var trackName: String = ""
    @Published var trackLocation: String = ""
    @Published var trackType: TrackType = .circuit
    @Published var startFinishCoordinate: CLLocationCoordinate2D?
    @Published var endPointCoordinate: CLLocationCoordinate2D?
    @Published var lineWidth: Double = 10
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // MARK: - Private Properties
    
    private let trackManager = TrackManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadTracks()
    }
    
    // MARK: - Public Methods
    
    func loadTracks() {
        tracks = trackManager.getAllTracks()
        filterTracks()
    }
    
    func filterTracks() {
        if searchText.isEmpty {
            filteredTracks = tracks.filter { $0.type == selectedTrackType }
        } else {
            filteredTracks = tracks.filter {
                $0.type == selectedTrackType &&
                ($0.name.lowercased().contains(searchText.lowercased()) ||
                 $0.location.lowercased().contains(searchText.lowercased()))
            }
        }
    }
    
    func selectTrack(_ track: Track) {
        selectedTrack = track
    }
    
    func saveTrack() {
        guard !trackName.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter a track name")
            return
        }
        
        guard let startCoordinate = startFinishCoordinate else {
            showAlert(title: "Missing Location", message: "Please set a start/finish line")
            return
        }
        
        let startPoint = GeoPoint(coordinate: startCoordinate)
        var endPoint: GeoPoint? = nil
        
        if trackType == .pointToPoint, let endCoordinate = endPointCoordinate {
            endPoint = GeoPoint(coordinate: endCoordinate)
        }
        
        let startFinishLine = StartFinishLine(
            point: startPoint,
            endPoint: endPoint,
            width: lineWidth
        )
        
        let newTrack = Track(
            name: trackName,
            type: trackType,
            startFinishLine: startFinishLine,
            location: trackLocation
        )
        
        trackManager.saveTrack(newTrack)
        loadTracks()
        
        // Reset creation fields
        resetTrackCreation()
        
        // Select the new track
        if let savedTrack = trackManager.getTrack(id: newTrack.id) {
            selectTrack(savedTrack)
        }
    }
    
    func deleteTrack(_ track: Track) {
        trackManager.deleteTrack(id: track.id)
        loadTracks()
        
        if selectedTrack?.id == track.id {
            selectedTrack = nil
        }
    }
    
    func updateMapRegion(for coordinate: CLLocationCoordinate2D) {
        mapRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    func setCurrentLocationAsStart(_ location: CLLocationCoordinate2D) {
        startFinishCoordinate = location
        updateMapRegion(for: location)
    }
    
    func setCurrentLocationAsEnd(_ location: CLLocationCoordinate2D) {
        endPointCoordinate = location
        
        // Update map region to show both points
        if let startCoord = startFinishCoordinate {
            let centerLat = (startCoord.latitude + location.latitude) / 2
            let centerLon = (startCoord.longitude + location.longitude) / 2
            
            let latDelta = abs(startCoord.latitude - location.latitude) * 1.5
            let lonDelta = abs(startCoord.longitude - location.longitude) * 1.5
            
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lonDelta, 0.01))
            )
        }
    }
    
    func resetTrackCreation() {
        trackName = ""
        trackLocation = ""
        trackType = .circuit
        startFinishCoordinate = nil
        endPointCoordinate = nil
        lineWidth = 10
    }
    
    // MARK: - Private Methods
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
