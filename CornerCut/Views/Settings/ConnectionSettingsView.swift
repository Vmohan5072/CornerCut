//
//  ConnectionSettingsView.swift
//  RaceBoxLapTimer
//
//  Created for RaceBox Lap Timer App
//

import SwiftUI
import CoreBluetooth

struct ConnectionSettingsView: View {
    @StateObject private var viewModel = ConnectionSettingsViewModel()
    @State private var selectedGPSSource: GPSSource = .internal
    @State private var showingDeviceScanner = false
    @State private var isRaceBoxConnecting = false
    @State private var isOBDConnecting = false
    
    var body: some View {
        Form {
            Section(header: Text("GPS SOURCE")) {
                Picker("GPS Source", selection: $selectedGPSSource) {
                    Text("Internal iPhone GPS").tag(GPSSource.internal)
                    Text("RaceBox External GPS").tag(GPSSource.raceBox)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedGPSSource) { newValue in
                    viewModel.setGPSSource(newValue)
                }
                
                if selectedGPSSource == .raceBox {
                    HStack {
                        Text("RaceBox Device")
                        Spacer()
                        Text(viewModel.connectedRaceBoxName ?? "Not Connected")
                            .foregroundColor(viewModel.connectedRaceBoxName != nil ? .primary : .secondary)
                    }
                    
                    Button(action: {
                        showingDeviceScanner = true
                    }) {
                        if viewModel.isRaceBoxConnected {
                            Text("Disconnect")
                                .foregroundColor(.red)
                        } else {
                            Text("Scan for Devices")
                                .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showingDeviceScanner) {
                        DeviceScannerView(
                            isScanning: $viewModel.isScanning,
                            discoveredDevices: viewModel.discoveredDevices,
                            onDeviceSelected: { peripheral in
                                viewModel.connectToRaceBox(peripheral)
                                isRaceBoxConnecting = true
                                showingDeviceScanner = false
                            },
                            onCancel: {
                                viewModel.stopScanning()
                                showingDeviceScanner = false
                            }
                        )
                    }
                }
            }
            
            Section(header: Text("OBD2 CONNECTION")) {
                Toggle("Enable OBD2", isOn: $viewModel.isOBDEnabled)
                
                if viewModel.isOBDEnabled {
                    HStack {
                        Text("OBD2 Device")
                        Spacer()
                        Text(viewModel.connectedOBDName ?? "Not Connected")
                            .foregroundColor(viewModel.connectedOBDName != nil ? .primary : .secondary)
                    }
                    
                    Button(action: {
                        if viewModel.isOBDConnected {
                            viewModel.disconnectOBD()
                        } else {
                            showingDeviceScanner = true
                        }
                    }) {
                        if viewModel.isOBDConnected {
                            Text("Disconnect")
                                .foregroundColor(.red)
                        } else {
                            Text("Scan for Devices")
                                .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showingDeviceScanner) {
                        DeviceScannerView(
                            isScanning: $viewModel.isScanning,
                            discoveredDevices: viewModel.discoveredDevices,
                            onDeviceSelected: { peripheral in
                                viewModel.connectToOBD(peripheral)
                                isOBDConnecting = true
                                showingDeviceScanner = false
                            },
                            onCancel: {
                                viewModel.stopScanning()
                                showingDeviceScanner = false
                            }
                        )
                    }
                }
            }
            
            if viewModel.isRaceBoxConnected {
                Section(header: Text("RACEBOX INFORMATION")) {
                    if let deviceInfo = viewModel.raceBoxDeviceInfo {
                        HStack {
                            Text("Model")
                            Spacer()
                            Text(deviceInfo.deviceType.rawValue)
                        }
                        
                        HStack {
                            Text("Firmware Version")
                            Spacer()
                            Text(deviceInfo.firmwareRevision)
                        }
                        
                        HStack {
                            Text("Serial Number")
                            Spacer()
                            Text(deviceInfo.serialNumber)
                        }
                        
                        if deviceInfo.deviceType == .miniS || deviceInfo.deviceType == .micro {
                            HStack {
                                Text("Recording Support")
                                Spacer()
                                Text("Available")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Button(action: {
                        viewModel.reconnectRaceBox()
                    }) {
                        Text("Refresh Connection")
                    }
                }
            }
        }
        .navigationTitle("Connection Setup")
        .onAppear {
            viewModel.loadCurrentSettings()
            selectedGPSSource = viewModel.currentGPSSource
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            Group {
                if isRaceBoxConnecting && !viewModel.isRaceBoxConnected {
                    ConnectionProgressView(title: "Connecting to RaceBox") {
                        isRaceBoxConnecting = false
                    }
                } else if isOBDConnecting && !viewModel.isOBDConnected {
                    ConnectionProgressView(title: "Connecting to OBD2") {
                        isOBDConnecting = false
                    }
                }
            }
        )
    }
}

struct DeviceScannerView: View {
    @Binding var isScanning: Bool
    let discoveredDevices: [CBPeripheral]
    let onDeviceSelected: (CBPeripheral) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if discoveredDevices.isEmpty {
                        if isScanning {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Scanning for devices...")
                            }
                        } else {
                            Text("No devices found")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(discoveredDevices, id: \.identifier) { device in
                            Button(action: {
                                onDeviceSelected(device)
                            }) {
                                HStack {
                                    Text(device.name ?? "Unknown Device")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Available Devices")
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button(isScanning ? "Stop" : "Scan", action: {
                    isScanning.toggle()
                })
            )
            .onAppear {
                isScanning = true
            }
            .onDisappear {
                isScanning = false
            }
        }
    }
}

struct ConnectionProgressView: View {
    let title: String
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text(title)
                    .font(.headline)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
                
                Button("Cancel", action: onCancel)
                    .padding(.top, 20)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .shadow(radius: 10)
        }
    }
}

enum GPSSource: String, CaseIterable {
    case `internal` = "internal"
    case raceBox = "raceBox"
}

struct ConnectionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConnectionSettingsView()
        }
    }
}
