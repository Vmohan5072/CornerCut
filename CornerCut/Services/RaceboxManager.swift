import Foundation
import CoreBluetooth
import Combine

/// A manager to handle RaceBox BLE connection and data parsing.
class RaceBoxManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties for SwiftUI
    @Published var isConnected: Bool = false
    @Published var currentSpeed: Double = 0
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var heading: Double = 0
    // Add more fields as needed (e.g., acceleration, satellites, etc.)
    
    // MARK: - Internal BLE references
    private var centralManager: CBCentralManager!
    private var raceBoxPeripheral: CBPeripheral?
    
    // Replace these with actual values from the RaceBox protocol doc
    private let raceBoxServiceUUID  = CBUUID(string: "FFF0")
    private let raceBoxDataUUID     = CBUUID(string: "FFF1")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// Begin scanning for the RaceBox device
    func startReadingData() {
        guard centralManager.state == .poweredOn else {
            print("Central not powered on")
            return
        }
        print("Scanning for RaceBox peripheral...")
        centralManager.scanForPeripherals(withServices: [raceBoxServiceUUID], options: nil)
    }
    
    /// Stop scanning or disconnect if necessary
    func stopReadingData() {
        if let peripheral = raceBoxPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        centralManager.stopScan()
    }
}

// MARK: - CBCentralManagerDelegate
extension RaceBoxManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("RaceBoxManager: Central is powered on.")
            // Optionally auto-start scanning, or wait for user action
        case .poweredOff:
            print("RaceBoxManager: Bluetooth is powered off.")
        case .resetting:
            print("RaceBoxManager: Central resetting.")
        case .unauthorized:
            print("RaceBoxManager: Bluetooth unauthorized.")
        case .unknown:
            print("RaceBoxManager: State unknown.")
        case .unsupported:
            print("RaceBoxManager: BLE unsupported on this device.")
        @unknown default:
            print("RaceBoxManager: An unknown state occurred.")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any],
                       rssi RSSI: NSNumber) {
        print("Discovered RaceBox peripheral: \(peripheral.name ?? "Unknown")")
        raceBoxPeripheral = peripheral
        raceBoxPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
        centralManager.stopScan() // Stop scanning once found
    }
    
    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        print("Connected to RaceBox peripheral.")
        isConnected = true
        peripheral.discoverServices([raceBoxServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        print("RaceBox disconnected: \(error?.localizedDescription ?? "No error")")
        isConnected = false
        // Optionally try reconnecting or inform user
    }
}

// MARK: - CBPeripheralDelegate
extension RaceBoxManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == raceBoxServiceUUID {
                peripheral.discoverCharacteristics([raceBoxDataUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == raceBoxDataUUID {
                // Subscribe to notifications
                peripheral.setNotifyValue(true, for: characteristic)
                print("RaceBox Data Characteristic found. Subscribing to notifications.")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Error updating value: \(error)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        // Parse the RaceBox data packet
        parseRaceBoxData(data)
    }
}

// MARK: - Data Parsing
extension RaceBoxManager {
    private func parseRaceBoxData(_ data: Data) {
        // According to the protocol doc, parse each field by offset
        // Example (pseudo-code with sample offsets/scales):
        
        // data[0..3]: Latitude (int32, scale 1e7)
        // data[4..7]: Longitude (int32, scale 1e7)
        // data[8..9]: Speed (uint16, scale 0.01 m/s)
        // data[10..11]: Heading (uint16, scale 0..35999 => 0..359.99 deg)
        // etc.
        
        let byteArray = [UInt8](data)
        // Always check if data.count is the size you expect
        
        if data.count < 12 {
            print("RaceBox data packet too short: \(data.count) bytes")
            return
        }
    
        
        let latRaw = Int32(byteArray[0])
            | Int32(byteArray[1]) << 8
            | Int32(byteArray[2]) << 16
            | Int32(byteArray[3]) << 24
        let lonRaw = Int32(byteArray[4])
            | Int32(byteArray[5]) << 8
            | Int32(byteArray[6]) << 16
            | Int32(byteArray[7]) << 24
        
        // For a scale factor of 1e7, degrees:
        let latDeg = Double(latRaw) / 1e7
        let lonDeg = Double(lonRaw) / 1e7
        
        // speed = bytes [8..9] => uint16, scale e.g. 0.01 m/s
        let speedRaw = UInt16(byteArray[8])
            | UInt16(byteArray[9]) << 8
        let speedValue = Double(speedRaw) * 0.01  // e.g. convert to m/s
        
        // heading = bytes [10..11] => 0..35999 => 0..359.99 deg
        let headingRaw = UInt16(byteArray[10])
            | UInt16(byteArray[11]) << 8
        let headingValue = Double(headingRaw) / 100.0
        
        // Update published properties
        DispatchQueue.main.async {
            self.latitude = latDeg
            self.longitude = lonDeg
            self.currentSpeed = speedValue
            self.heading = headingValue
        }
        
    }
}
