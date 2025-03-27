
//
//  BluetoothManager.swift
//  RaceBoxLapTimer
//
//  Created for RaceBox Lap Timer App
//

import Foundation
import Combine
import CoreBluetooth

class BluetoothManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var discoveredDevices: [CBPeripheral] = []
    
    // MARK: - Device Managers
    
    let raceBoxManager = RaceBoxManager()
    var obdManager: OBDManager?
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupRaceBoxManagerSubscriptions()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func startScanningForDevices() {
        guard centralManager.state == .poweredOn else { return }
        
        isScanning = true
        discoveredDevices.removeAll()
        
        // Scan for all devices
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // Auto-stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanningForDevices()
        }
    }
    
    func stopScanningForDevices() {
        guard isScanning else { return }
        
        centralManager.stopScan()
        isScanning = false
    }
    
    func connectToRaceBox(_ peripheral: CBPeripheral) {
        stopScanningForDevices()
        raceBoxManager.connect(to: peripheral)
    }
    
    func disconnectRaceBox() {
        raceBoxManager.disconnect()
    }
    
    // MARK: - Private Methods
    
    private func setupRaceBoxManagerSubscriptions() {
        raceBoxManager.$connectionState
            .sink { [weak self] state in
                switch state {
                case .connected:
                    // Read device info when connected
                    self?.raceBoxManager.readDeviceInfo()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothEnabled = central.state == .poweredOn
        
        if central.state != .poweredOn {
            isScanning = false
            discoveredDevices.removeAll()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Add device if not already in the list
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }
}
