import Foundation
import Combine

final class OBD2Manager: ObservableObject {
    static let shared = OBD2Manager() // Singleton instance

    @Published var currentSpeed: Double = 0
    @Published var currentRPM: Double = 0
    @Published var throttle: Double = 0
    @Published var brake: Double = 0
    
    private init() {} // Prevent external instantiation

    func startReadingData() {
        // 1. Connect to OBD dongle
        // 2. Subscribe to OBD2 data
        // 3. Parse PIDs
        print("OBD2 reading started.")
    }
    
    func stopReadingData() {
        // Stop reading data and cleanup
        print("OBD2 reading stopped.")
    }
}
