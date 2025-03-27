//
//  CreateTrackView.swift
//  RaceBoxLapTimer
//

import SwiftUI
import MapKit

struct CreateTrackView: View {
    @ObservedObject var viewModel: TrackViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var selectedPointType: PointType = .start
    
    enum PointType {
        case start
        case end
    }
    
    var body: some View {
        Form {
            Section(header: Text("Track Information")) {
                TextField("Track Name", text: $viewModel.trackName)
                TextField("Location (optional)", text: $viewModel.trackLocation)
                
                Picker("Track Type", selection: $viewModel.trackType) {
                    ForEach(TrackType.allCases, id: \.self) { type in
                        Text(type.description).tag(type)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
            }
            
            Section(header: Text("Start/Finish Line")) {
                // Map for visualization
                Map(coordinateRegion: $viewModel.mapRegion, showsUserLocation: true, annotationItems: getAnnotations()) { item in
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
                .frame(height: 200)
                .cornerRadius(8)
                
                if viewModel.trackType == .pointToPoint {
                    Picker("Setting Point", selection: $selectedPointType) {
                        Text("Start Line").tag(PointType.start)
                        Text("End Line").tag(PointType.end)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Button(action: {
                    if let location = locationManager.location?.coordinate {
                        if selectedPointType == .start || viewModel.trackType == .circuit {
                            viewModel.setCurrentLocationAsStart(location)
                        } else {
                            viewModel.setCurrentLocationAsEnd(location)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text(selectedPointType == .start ? "Set Start Line Here" : "Set End Line Here")
                    }
                }
                .disabled(locationManager.location == nil)
                
                if viewModel.trackType == .circuit {
                    Stepper(value: $viewModel.lineWidth, in: 5...50, step: 5) {
                        Text("Line Width: \(Int(viewModel.lineWidth)) meters")
                    }
                }
            }
            
            if locationManager.authorizationStatus != .authorizedWhenInUse && locationManager.authorizationStatus != .authorizedAlways {
                Section(header: Text("Location Access")) {
                    Text("Please enable location access to set track points.")
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            locationManager.startUpdatingLocation()
            
            // If we have the user's location, center the map there
            if let location = locationManager.location?.coordinate {
                viewModel.updateMapRegion(for: location)
            }
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
        }
    }
    
    private func getAnnotations() -> [TrackPointAnnotation] {
        var annotations = [TrackPointAnnotation]()
        
        if let startCoord = viewModel.startFinishCoordinate {
            annotations.append(
                TrackPointAnnotation(
                    id: "start",
                    coordinate: startCoord,
                    isStart: true,
                    isEnd: false
                )
            )
        }
        
        if viewModel.trackType == .pointToPoint, let endCoord = viewModel.endPointCoordinate {
            annotations.append(
                TrackPointAnnotation(
                    id: "end",
                    coordinate: endCoord,
                    isStart: false,
                    isEnd: true
                )
            )
        }
        
        return annotations
    }
}

    struct CreateTrackView_Previews: PreviewProvider {
        static var previews: some View {
            CreateTrackView(viewModel: TrackViewModel())
        }
    }
