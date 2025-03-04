import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var raceBoxManager: RaceBoxManager
    @EnvironmentObject var obd2Manager: OBD2Manager
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            StraightlineView()
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }
                .tag(2)

            SettingsView(
                bluetoothManager: bluetoothManager,
                obd2Manager: obd2Manager,
                raceBoxManager: raceBoxManager
            )
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            // Set global appearance for the tab bar
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            // Attempt to reconnect to any previously connected devices
            if bluetoothManager.previouslyConnectedDeviceExists() {
                bluetoothManager.reconnectToPreviousDevice()
            }
        }
        .environmentObject(locationManager)
        .environmentObject(raceBoxManager)
        .environmentObject(obd2Manager)
        .environmentObject(bluetoothManager)
    }
}

// Preview for SwiftUI canvas
#Preview {
    MainTabView()
        .environmentObject(LocationManager())
        .environmentObject(RaceBoxManager.shared)
        .environmentObject(OBD2Manager.shared)
        .environmentObject(BluetoothManager.shared)
}
