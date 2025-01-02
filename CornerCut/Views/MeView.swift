import SwiftUI

struct MeView: View {
    @State private var useMetricUnits = false
    @State private var garage: [String] = ["Example Vehicle"]
    @State private var showSettings = false // State for showing the SettingsView

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Garage")) {
                    ForEach(garage, id: \.self) { vehicle in
                        Text(vehicle)
                    }
                    Button("Add Vehicle") {
                        // TODO: Add function to save vehicles
                    }
                }
                
                Section(header: Text("Connections")) {
                    Button("Pair RaceBox") {
                        // TODO: Add function to pair RaceBox
                    }
                    Button("Pair OBD Reader") {
                        // TODO: Add function to pair OBD Reader
                    }
                }
            }
            .navigationTitle("Me")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.blue)
                    }
                }
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView(
                    bluetoothManager: BluetoothManager.shared,
                    obd2Manager: OBD2Manager.shared,
                    raceBoxManager: RaceBoxManager.shared
                )
            }
        }
    }
}
