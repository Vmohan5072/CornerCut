import SwiftUI
import SwiftData

@main
struct CornerCutApp: App {
    // SwiftData container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Session.self,
            Lap.self,
            TelemetryData.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // Managers
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var raceBoxManager = RaceBoxManager.shared
    @StateObject private var obd2Manager = OBD2Manager.shared
    @StateObject private var bluetoothManager = BluetoothManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(locationManager)
                .environmentObject(raceBoxManager)
                .environmentObject(obd2Manager)
                .environmentObject(bluetoothManager)
                .modelContainer(sharedModelContainer)
        }
    }
}
