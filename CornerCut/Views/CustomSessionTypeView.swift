import SwiftUI
import MapKit
import CoreLocation

enum CustomSessionType {
    case singlePoint   // Circuit racing with same start/finish line
    case pointToPoint  // Different start and end points (autocross, hillclimb, etc.)
}

struct CustomSessionTypeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CustomSessionType? = nil
    @State private var showMapView = false
    @State private var locationA: CLLocationCoordinate2D? = nil
    @State private var locationB: CLLocationCoordinate2D? = nil
    
    // Completion handler for when a session is configured
    let onSessionConfigured: (CustomSessionType, CLLocationCoordinate2D?, CLLocationCoordinate2D?) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("Custom Session Type")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select the type of custom session you want to create")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top)
            
            // Session Type Options
            VStack(spacing: 16) {
                // Circuit/Single Point Option
                Button {
                    selectedType = .singlePoint
                    showMapView = true
                } label: {
                    SessionTypeCard(
                        title: "Circuit / Single Point",
                        description: "Track with the same start and finish line. Uses a single timing point.",
                        iconName: "circle.dashed",
                        color: .blue,
                        isSelected: selectedType == .singlePoint
                    )
                }
                
                // Point to Point Option
                Button {
                    selectedType = .pointToPoint
                    showMapView = true
                } label: {
                    SessionTypeCard(
                        title: "Point to Point",
                        description: "Different start and finish points, like autocross, hillclimb, or rally stage.",
                        iconName: "arrow.left.and.right",
                        color: .green,
                        isSelected: selectedType == .pointToPoint
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Button to start without specific locations
            Button {
                onSessionConfigured(selectedType ?? .singlePoint, locationA, locationB)
                dismiss()
            } label: {
                Text("Start Immediately Without Setting Points")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .opacity(selectedType != nil ? 1.0 : 0.0)
            .disabled(selectedType == nil)
            .padding(.bottom)
        }
        .navigationTitle("Custom Session")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMapView) {
            NavigationView {
                LocationPickerView(
                    sessionType: selectedType ?? .singlePoint,
                    locationA: $locationA,
                    locationB: $locationB,
                    onSave: { locA, locB in
                        locationA = locA
                        locationB = locB
                        showMapView = false
                        
                        // If we have the required locations, start the session
                        if let type = selectedType {
                            if type == .singlePoint && locationA != nil {
                                onSessionConfigured(type, locationA, nil)
                                dismiss()
                            } else if type == .pointToPoint && locationA != nil && locationB != nil {
                                onSessionConfigured(type, locationA, locationB)
                                dismiss()
                            }
                        }
                    }
                )
                .navigationTitle(selectedType == .singlePoint ? "Set Timing Point" : "Set Start & End Points")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showMapView = false
                        }
                    }
                }
            }
        }
    }
}

struct SessionTypeCard: View {
    let title: String
    let description: String
    let iconName: String
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(color)
                    .font(.title2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
    }
}

struct LocationPickerView: View {
    let sessionType: CustomSessionType
    @Binding var locationA: CLLocationCoordinate2D?
    @Binding var locationB: CLLocationCoordinate2D?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isSettingPointA = true
    @State private var userTrackingMode: MapUserTrackingMode = .follow
    
    let onSave: (CLLocationCoordinate2D?, CLLocationCoordinate2D?) -> Void
    
    var body: some View {
        ZStack {
            // Map view
            Map(coordinateRegion: $region, showsUserLocation: true, userTrackingMode: $userTrackingMode, annotationItems: getAnnotations()) { annotation in
                MapMarker(coordinate: annotation.coordinate, tint: annotation.isPointA ? .blue : .green)
            }
            .edgesIgnoringSafeArea(.bottom)
            
            // Bottom Panel
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    if sessionType == .pointToPoint {
                        // For point-to-point, show which point we're setting
                        HStack {
                            Spacer()
                            
                            Button {
                                isSettingPointA = true
                            } label: {
                                Text("Start Point")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSettingPointA ? Color.blue : Color.gray.opacity(0.3))
                                    .foregroundColor(isSettingPointA ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            
                            Button {
                                isSettingPointA = false
                            } label: {
                                Text("End Point")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(!isSettingPointA ? Color.green : Color.gray.opacity(0.3))
                                    .foregroundColor(!isSettingPointA ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Text(sessionType == .singlePoint ? "Tap to set the timing point" : isSettingPointA ? "Tap to set the start point" : "Tap to set the end point")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Set current location button
                    Button {
                        setCurrentLocation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Use Current Location")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    
                    // Save button
                    Button {
                        saveLocations()
                    } label: {
                        Text("Save and Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(canSave() ? Color.green : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!canSave())
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
                .padding()
            }
        }
        .onTapGesture { location in
            // Convert tap to map coordinate
            let coordinate = convertToCoordinate(location)
            
            if sessionType == .singlePoint {
                locationA = coordinate
            } else {
                if isSettingPointA {
                    locationA = coordinate
                } else {
                    locationB = coordinate
                }
            }
        }
    }
    
    private func getAnnotations() -> [MapAnnotation] {
        var annotations: [MapAnnotation] = []
        
        if let locationA = locationA {
            annotations.append(MapAnnotation(id: "A", coordinate: locationA, isPointA: true))
        }
        
        if let locationB = locationB {
            annotations.append(MapAnnotation(id: "B", coordinate: locationB, isPointA: false))
        }
        
        return annotations
    }
    
    private func setCurrentLocation() {
        // Get current user location from the map region
        let currentLocation = region.center
        
        if sessionType == .singlePoint {
            locationA = currentLocation
        } else {
            if isSettingPointA {
                locationA = currentLocation
            } else {
                locationB = currentLocation
            }
        }
    }
    
    private func saveLocations() {
        if canSave() {
            onSave(locationA, locationB)
        }
    }
    
    private func canSave() -> Bool {
        if sessionType == .singlePoint {
            return locationA != nil
        } else {
            return locationA != nil && locationB != nil
        }
    }
    
    // This is a stub - in a real implementation, you would convert the tap location to a map coordinate
    private func convertToCoordinate(_ location: CGPoint) -> CLLocationCoordinate2D {
        // In a real implementation, this would convert a screen point to a map coordinate
        // For now, we'll just use the current center coordinate
        return region.center
    }
}

struct MapAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isPointA: Bool
}
