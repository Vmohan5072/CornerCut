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
    @StateObject var locationManager = LocationManager()
    @StateObject var raceBoxManager = RaceBoxManager()
    @StateObject var obd2Manager = OBD2Manager()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(locationManager)
                .environmentObject(raceBoxManager)
                .environmentObject(obd2Manager)
                .modelContainer(sharedModelContainer)
        }
    }
}
