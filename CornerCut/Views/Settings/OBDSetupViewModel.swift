//
//  OBDSetupViewModel.swift
//  CornerCut
//

import Foundation
import CoreBluetooth
import Combine
import SwiftUI

class OBDSetupViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isOBDEnabled = false
    @Published var isConnected = false
    @Published var connectionStatusText = "Not Connected"
    @Published var connectionStatusColor = Color.red
    @Published var adapterName = "Unknown"
    @Published var supportedParameters: [OBDParameter] = []
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isScanning = false
    @Published var parameterValues: [String: String] = [:]
    
    // MARK: - Dependencies
    
    private let bluetoothManager: BluetoothManager
    private let settingsManager: SettingsManager
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    var supportedParametersCount: Int {
        return supportedParameters.count
    }
    
    // MARK: - Initialization
    
    init(bluetoothManager: BluetoothManager = BluetoothManager(),
         settingsManager: SettingsManager = SettingsManager.shared) {
        self.bluetoothManager = bluetoothManager
        self.settingsManager = settingsManager
        
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    func loadCurrentSettings() {
        isOBDEnabled = settingsManager.isOBDEnabled
    }
    
    func updateOBDEnabled(_ enabled: Bool) {
        isOBDEnabled = enabled
        settingsManager.isOBDEnabled = enabled
        
        if !enabled && isConnected {
            disconnect()
        }
    }
    
    func startScanning() {
        isScanning = true
        bluetoothManager.startScanningForDevices()
    }
    
    func stopScanning() {
        isScanning = false
        bluetoothManager.stopScanningForDevices()
    }
    
    func connect(to peripheral: CBPeripheral) {
        bluetoothManager.connectToOBD(peripheral)
    }
    
    func disconnect() {
        bluetoothManager.disconnectOBD()
    }
    
    func refreshParameters() {
        // Restart polling to refresh data
        bluetoothManager.obdManager.stopPolling()
        bluetoothManager.obdManager.startPolling()
    }
    
    func getParameterValue(_ parameter: OBDParameter) -> String? {
        return parameterValues[parameter.id]
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Monitor OBD connection state
        bluetoothManager.obdManager.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .connected:
                    self.isConnected = true
                    self.connectionStatusText = "Connected"
                    self.connectionStatusColor = Color.green
                    
                    if let device = self.bluetoothManager.obdManager.obdDevice {
                        self.adapterName = device.name ?? "OBD Adapter"
                    }
                    
                case .connecting:
                    self.isConnected = false
                    self.connectionStatusText = "Connecting..."
                    self.connectionStatusColor = Color.yellow
                    
                case .initializing:
                    self.isConnected = false
                    self.connectionStatusText = "Initializing..."
                    self.connectionStatusColor = Color.yellow
                    
                case .failed(let error):
                    self.isConnected = false
                    self.connectionStatusText = "Connection Failed"
                    self.connectionStatusColor = Color.red
                    print("OBD connection error: \(error.localizedDescription)")
                    
                default:
                    self.isConnected = false
                    self.connectionStatusText = "Not Connected"
                    self.connectionStatusColor = Color.red
                }
            }
            .store(in: &cancellables)
        
        // Monitor supported parameters
        bluetoothManager.obdManager.$supportedParameters
            .receive(on: RunLoop.main)
            .sink { [weak self] parameters in
                self?.supportedParameters = parameters
            }
            .store(in: &cancellables)
        
        // Monitor discovered devices
        bluetoothManager.$discoveredDevices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                self?.discoveredDevices = devices
            }
            .store(in: &cancellables)
        
        // Monitor scanning state
        bluetoothManager.$isScanning
            .receive(on: RunLoop.main)
            .sink { [weak self] isScanning in
                self?.isScanning = isScanning
            }
            .store(in: &cancellables)
        
        // Monitor OBD responses
        bluetoothManager.obdManager.$latestResponses
            .receive(on: RunLoop.main)
            .sink { [weak self] responses in
                guard let self = self else { return }
                
                var newValues: [String: String] = [:]
                
                for (id, response) in responses {
                    newValues[id] = response.formattedValue
                }
                
                self.parameterValues = newValues
            }
            .store(in: &cancellables)
    }
}
