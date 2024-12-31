import Foundation

class OBD2Manager: ObservableObject {
    // Template for OBD manager
    
    @Published var currentSpeed: Double = 0
    @Published var currentRPM: Double = 0
    @Published var throttle: Double = 0
    @Published var brake: Double = 0
    
    func startReadingData() {
        // 1. Connect to OBD dongle
        // 2. Subscribe to OBD2 data
        // 3. Parse PIDs
    }
    
    func stopReadingData() {
        // Stop reading data and cleanup
    }
}
