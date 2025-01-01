import SwiftUI

struct MeView: View {
    @State private var useMetricUnits = false
    @State private var garage: [String] = ["Example Vehicle"]

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
                
                Section(header: Text("Units")) {
                    Toggle("Use Metric Units", isOn: $useMetricUnits)
                } //TODO: Change functionality to toggle units
                
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
        }
    }
}
