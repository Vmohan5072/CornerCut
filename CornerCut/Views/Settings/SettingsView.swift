//
//  SettingsView.swift
//  CornerCut
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        Form {
            Section(header: Text("CONNECTIONS")) {
                NavigationLink(destination: ConnectionSettingsView()) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                        Text("GPS & OBD Setup")
                    }
                }
                
                NavigationLink(destination: OBDSetupView(viewModel: OBDSetupViewModel())) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.orange)
                        Text("OBD2 Data Configuration")
                    }
                }
            }
            
            Section(header: Text("DISPLAY")) {
                Toggle("Dark Mode", isOn: $viewModel.isDarkModeEnabled)
                    .onChange(of: viewModel.isDarkModeEnabled) { newValue in
                        viewModel.updateDarkMode(newValue)
                    }
                
                Picker("Unit System", selection: $viewModel.unitSystem) {
                    Text("Imperial (mph, ft)").tag(UnitSystem.imperial)
                    Text("Metric (km/h, m)").tag(UnitSystem.metric)
                }
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: viewModel.unitSystem) { newValue in
                    viewModel.updateUnitSystem(newValue)
                }
            }
            
            Section(header: Text("RECORDING")) {
                Picker("Sample Rate", selection: $viewModel.sampleRate) {
                    ForEach(SampleRate.allCases, id: \.self) { rate in
                        Text(rate.description).tag(rate)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: viewModel.sampleRate) { newValue in
                    viewModel.updateSampleRate(newValue)
                }
            }
            
            Section(header: Text("DATA MANAGEMENT")) {
                NavigationLink(destination: Text("Coming soon...")) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.green)
                        Text("Export Data")
                    }
                }
                
                NavigationLink(destination: Text("Coming soon...")) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.red)
                        Text("Reset Application Data")
                    }
                }
            }
            
            Section(header: Text("ABOUT")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                        .foregroundColor(.secondary)
                }
                
                NavigationLink(destination: Text("Terms and privacy policy would go here")) {
                    Text("Terms & Privacy Policy")
                }
                
                NavigationLink(destination: Text("Support information would go here")) {
                    Text("Help & Support")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
