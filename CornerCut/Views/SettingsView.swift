import SwiftUI

struct SettingsView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var obd2Manager: OBD2Manager
    @ObservedObject var raceBoxManager: RaceBoxManager

    @Environment(\.dismiss) var dismiss
    @AppStorage("useMetricUnits") private var useMetricUnits = false // Persistent storage for units

    @State private var useExternalGPS = false

    var body: some View {
        NavigationView {
            Form {
                // GPS Settings Section
                Section(header: Text("GPS Settings")) {
                    Toggle("Use External GPS (RaceBox)", isOn: $useExternalGPS)
                        .onChange(of: useExternalGPS, initial: true) { oldValue, newValue in
                            if newValue {
                                raceBoxManager.startReadingData()
                            } else {
                                raceBoxManager.stopReadingData()
                            }
                        }
                }

                // OBD2 Connection Section
                Section(header: Text("OBD2 Connection")) {
                    if bluetoothManager.isConnected {
                        Text("OBD2 Connected")
                            .foregroundColor(.green)
                    } else {
                        Button("Scan/Connect OBD2") {
                            bluetoothManager.startScan()
                        }
                    }
                }

                // Units Section
                Section(header: Text("Units")) {
                    Toggle("Use Metric Units", isOn: $useMetricUnits)
                        .onChange(of: useMetricUnits, initial: true) { oldValue, newValue in
                            print("Units switched from \(oldValue ? "Metric" : "Imperial") to \(newValue ? "Metric" : "Imperial")")
                            obd2Manager.switchUnits(toMetric: newValue)
                        }
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
