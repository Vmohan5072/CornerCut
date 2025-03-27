//
//  OBDSetupView.swift
//  CornerCut
//

import SwiftUI
import CoreBluetooth

struct OBDSetupView: View {
    @ObservedObject var viewModel: OBDSetupViewModel
    @State private var showScanSheet = false
    
    var body: some View {
        Form {
            Section(header: Text("OBD CONNECTION")) {
                Toggle("Enable OBD2", isOn: $viewModel.isOBDEnabled)
                    .onChange(of: viewModel.isOBDEnabled) { newValue in
                        viewModel.updateOBDEnabled(newValue)
                    }
                
                if viewModel.isOBDEnabled {
                    HStack {
                        Text("Connection Status")
                        Spacer()
                        Text(viewModel.connectionStatusText)
                            .foregroundColor(viewModel.connectionStatusColor)
                    }
                    
                    Button(action: {
                        if viewModel.isConnected {
                            viewModel.disconnect()
                        } else {
                            showScanSheet = true
                        }
                    }) {
                        Text(viewModel.isConnected ? "Disconnect" : "Connect Adapter")
                            .foregroundColor(viewModel.isConnected ? .red : .blue)
                    }
                }
            }
            
            if viewModel.isConnected {
                Section(header: Text("DEVICE INFORMATION")) {
                    HStack {
                        Text("Adapter Name")
                        Spacer()
                        Text(viewModel.adapterName)
                    }
                    
                    HStack {
                        Text("Supported Parameters")
                        Spacer()
                        Text("\(viewModel.supportedParametersCount)")
                    }
                }
                
                Section(header: Text("AVAILABLE DATA")) {
                    ForEach(viewModel.supportedParameters, id: \.id) { param in
                        HStack {
                            Text(param.name)
                            Spacer()
                            if let value = viewModel.getParameterValue(param) {
                                Text(value)
                            } else {
                                Text("--")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section(header: Text("ACTIONS")) {
                    Button(action: {
                        viewModel.refreshParameters()
                    }) {
                        Text("Refresh Data")
                    }
                }
            }
        }
        .navigationTitle("OBD2 Setup")
        .sheet(isPresented: $showScanSheet) {
            DeviceScannerView(
                isScanning: $viewModel.isScanning,
                discoveredDevices: viewModel.discoveredDevices,
                onDeviceSelected: { peripheral in
                    viewModel.connect(to: peripheral)
                    showScanSheet = false
                },
                onCancel: {
                    viewModel.stopScanning()
                    showScanSheet = false
                }
            )
        }
        .onAppear {
            viewModel.loadCurrentSettings()
        }
    }
}

struct OBDSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OBDSetupView(viewModel: OBDSetupViewModel())
        }
    }
}
