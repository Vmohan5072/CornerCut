import SwiftUI
import SwiftData

@main
struct CornerCutApp: App {
    // MARK: - SwiftData Model Container
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
    
    // MARK: - Managers
    @StateObject var locationManager = LocationManager()
    @StateObject var raceBoxManager = RaceBoxManager()
    @StateObject var obd2Manager = OBD2Manager()
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Provide the managers as environment objects
                .environmentObject(locationManager)
                .environmentObject(raceBoxManager)
                .environmentObject(obd2Manager)
                .modelContainer(sharedModelContainer)
        }
    }
}
