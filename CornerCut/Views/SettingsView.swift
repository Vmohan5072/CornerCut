import SwiftUI
// TODO: Route from MeView to SettingsView
struct SettingsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var obd2Manager: OBD2Manager
    @ObservedObject var raceBoxManager: RaceBoxManager
    
    @Environment(\.dismiss) var dismiss
    
    @State private var useExternalGPS = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GPS Settings")) {
                    Toggle("Use External GPS (RaceBox)", isOn: $useExternalGPS)
                        .onChange(of: useExternalGPS) { oldValue, newValue in
                            // handle toggling external GPS usage
                            if newValue {
                                raceBoxManager.startReadingData()
                            } else {
                                raceBoxManager.stopReadingData()
                            }
                        }
                }
                
                Section(header: Text("OBD2 Connection")) {
                    if bluetoothManager.isConnected {
                        Text("OBD2 Connected")
                    } else {
                        Button("Scan/Connect OBD2") {
                            bluetoothManager.startScan()
                        }
                    }
                }
                
                Section(header: Text("Units")) {
                    // e.g. metric / superior freedom units
                }
                
                Section(header: Text("Appearance")) {
                    // Dark mode toggles
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
