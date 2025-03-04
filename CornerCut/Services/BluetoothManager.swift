import Foundation
import CoreBluetooth
import Combine
import SwiftUI

final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager() // Singleton instance

    // MARK: - Published Properties
    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectionError: String?
    
    // MARK: - User Settings
    private var lastConnectedDeviceUUID: String? {
        get {
            return UserDefaults.standard.string(forKey: "lastConnectedDeviceUUID")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastConnectedDeviceUUID")
        }
    }
    // MARK: - Internal Properties
    private var centralManager: CBCentralManager!
    private var targetServiceUUID: CBUUID?
    private var targetCharacteristicUUID: CBUUID?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var serviceDiscoveryCallback: ((CBService) -> Void)?
    private var characteristicDiscoveryCallback: ((CBCharacteristic) -> Void)?
    private var connectionCallback: ((Bool) -> Void)?
    private var connectionTimeoutTimer: Timer?
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for Bluetooth devices with optional filtering
    func startScan(withServices services: [CBUUID]? = nil) {
        guard centralManager.state == .poweredOn else {
            connectionError = "Bluetooth is not powered on"
            return
        }
        
        // Clear any previous discoveries
        discoveredPeripherals.removeAll()
        
        // Start the scan
        isScanning = true
        centralManager.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        // Set a timeout for the scan
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.stopScan()
        }
    }
    
    /// Stop scanning for Bluetooth devices
    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }
    
    /// Connect to a specific peripheral
    func connect(to peripheral: CBPeripheral, completion: ((Bool) -> Void)? = nil) {
        // Save callback
        connectionCallback = completion
        
        // Start connection timeout timer
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if self.connectedPeripheral == nil {
                self.connectionError = "Connection timeout"
                self.connectionCallback?(false)
                self.connectionCallback = nil
            }
        }
        
        // Connect to peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Disconnect from the currently connected peripheral
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// Discover services on the connected peripheral
    func discoverServices(_ serviceUUIDs: [CBUUID]? = nil, completion: ((CBService) -> Void)? = nil) {
        guard let peripheral = connectedPeripheral else {
            connectionError = "No peripheral connected"
            return
        }
        
        serviceDiscoveryCallback = completion
        peripheral.discoverServices(serviceUUIDs)
    }
    
    /// Discover characteristics on a specific service
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]? = nil, for service: CBService, completion: ((CBCharacteristic) -> Void)? = nil) {
        guard let peripheral = connectedPeripheral else {
            connectionError = "No peripheral connected"
            return
        }
        
        characteristicDiscoveryCallback = completion
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
    }
    
    /// Send a command (string) to the connected device
    func sendCommand(_ command: String) {
        guard let data = command.data(using: .utf8) else {
            print("Could not convert command to data")
            return
        }
        
        sendData(data)
    }
    
    /// Send raw data to the connected device
    func sendData(_ data: Data) {
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            connectionError = "No peripheral or write characteristic available"
            return
        }
        
        // Determine write type
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        
        peripheral.writeValue(data, for: characteristic, type: writeType)
    }
    
    /// Check if a previously connected device exists
    func previouslyConnectedDeviceExists() -> Bool {
        return lastConnectedDeviceUUID != nil
    }
    
    /// Attempt to reconnect to the previously connected device
    func reconnectToPreviousDevice() {
        guard let uuidString = lastConnectedDeviceUUID,
              let uuid = UUID(uuidString: uuidString) else {
            return
        }
        
        // Start scanning
        startScan()
        
        // Setup a timeout for reconnection attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }
            
            // Check discovered peripherals for a match
            if let peripheral = self.discoveredPeripherals.first(where: { $0.identifier == uuid }) {
                self.stopScan()
                self.connect(to: peripheral)
            } else {
                self.stopScan()
            }
        }
    }
    
    /// Configure for OBD communication
    func configureForOBD() {
        targetServiceUUID = CBUUID(string: "FFF0") // Example OBD Service UUID
        targetCharacteristicUUID = CBUUID(string: "FFF1") // Example OBD Characteristic UUID
    }
    
    /// Configure for RaceBox communication
    func configureForRaceBox() {
        targetServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E") // RaceBox UART Service
        targetCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // RaceBox TX Characteristic
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            isConnected = false
            connectionError = "Bluetooth is powered off"
        case .resetting:
            print("Bluetooth is resetting")
            connectionError = "Bluetooth is resetting"
        case .unauthorized:
            print("Bluetooth is unauthorized")
            connectionError = "Bluetooth access is unauthorized"
        case .unknown:
            print("Bluetooth state is unknown")
            connectionError = "Bluetooth state is unknown"
        case .unsupported:
            print("Bluetooth is unsupported on this device")
            connectionError = "Bluetooth is unsupported on this device"
        @unknown default:
            print("Unknown Bluetooth state")
            connectionError = "Unknown Bluetooth state"
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        
        // Add to discovered peripherals if not already present
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        
        // Cancel timeout timer
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        // Update state
        connectedPeripheral = peripheral
        isConnected = true
        
        // Save device for later reconnection
        lastConnectedDeviceUUID = peripheral.identifier.uuidString
        
        // Discover services if target service is set
        if let serviceUUID = targetServiceUUID {
            peripheral.discoverServices([serviceUUID])
        }
        
        // Call completion handler
        connectionCallback?(true)
        connectionCallback = nil
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        
        // Cancel timeout timer
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        // Update state
        isConnected = false
        connectionError = error?.localizedDescription ?? "Failed to connect"
        
        // Call completion handler
        connectionCallback?(false)
        connectionCallback = nil
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("Disconnected from peripheral: \(error?.localizedDescription ?? "No error")")
        
        // Update state
        if peripheral.identifier == connectedPeripheral?.identifier {
            connectedPeripheral = nil
            isConnected = false
            writeCharacteristic = nil
            notifyCharacteristic = nil
            
            if let error = error {
                connectionError = "Disconnected: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        
        if let error = error {
            print("Error discovering services: \(error)")
            connectionError = "Error discovering services: \(error.localizedDescription)"
            return
        }
        
        guard let services = peripheral.services else {
            print("No services found")
            return
        }
        
        print("Discovered \(services.count) services")
        
        // Process discovered services
        for service in services {
            print("Service: \(service.uuid)")
            
            // If this is our target service, discover characteristics
            if service.uuid == targetServiceUUID {
                if let characteristicUUID = targetCharacteristicUUID {
                    peripheral.discoverCharacteristics([characteristicUUID], for: service)
                } else {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
            
            // Call service discovery callback if set
            serviceDiscoveryCallback?(service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        if let error = error {
            print("Error discovering characteristics: \(error)")
            connectionError = "Error discovering characteristics: \(error.localizedDescription)"
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("No characteristics found")
            return
        }
        
        print("Discovered \(characteristics.count) characteristics for service \(service.uuid)")
        
        for characteristic in characteristics {
            print("Characteristic: \(characteristic.uuid)")
            
            // Check for RaceBox characteristics
            if service.uuid == CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E") {
                // RaceBox UART service
                if characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") {
                    // TX characteristic (device -> phone)
                    notifyCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if characteristic.uuid == CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") {
                    // RX characteristic (phone -> device)
                    writeCharacteristic = characteristic
                }
            }
            
            // Check for OBD characteristics
            if service.uuid == CBUUID(string: "FFF0") {
                // Example OBD service
                if characteristic.uuid == CBUUID(string: "FFF1") {
                    // Example OBD characteristic
                    writeCharacteristic = characteristic
                    notifyCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
            
            // Call characteristic discovery callback if set
            characteristicDiscoveryCallback?(characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        if let error = error {
            print("Error updating value: \(error)")
            return
        }
        
        guard let data = characteristic.value else {
            print("No data received")
            return
        }
        
        // Process the received data
        if characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") {
            // RaceBox TX characteristic data
            RaceBoxManager.shared.parseRaceBoxData(data)
        } else if characteristic.uuid == CBUUID(string: "FFF1") {
            // OBD characteristic data
            OBD2Manager.shared.parseOBDResponse(data)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        if let error = error {
            print("Error writing value: \(error)")
            connectionError = "Error writing to device: \(error.localizedDescription)"
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        if let error = error {
            print("Error updating notification state: \(error)")
            connectionError = "Error setting up notifications: \(error.localizedDescription)"
            return
        }
        
        if characteristic.isNotifying {
            print("Notifications enabled for \(characteristic.uuid)")
        } else {
            print("Notifications disabled for \(characteristic.uuid)")
        }
    }
}
