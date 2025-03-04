import Foundation
import CoreBluetooth
import Combine

/// A manager to handle RaceBox BLE connection and data parsing.
class RaceBoxManager: NSObject, ObservableObject {
    
    // Singleton instance
    static let shared = RaceBoxManager()
    
    // MARK: - Published Properties for SwiftUI
    @Published var isConnected: Bool = false
    @Published var currentSpeed: Double = 0   // Speed in m/s
    @Published var latitude: Double = 0       // Latitude in degrees
    @Published var longitude: Double = 0      // Longitude in degrees
    @Published var heading: Double = 0        // Heading in degrees
    @Published var altitude: Double = 0       // Altitude in meters
    @Published var gForceX: Double = 0        // G-force X (front/back) in g
    @Published var gForceY: Double = 0        // G-force Y (left/right) in g
    @Published var gForceZ: Double = 0        // G-force Z (up/down) in g
    @Published var rotationX: Double = 0      // Rotation rate X (roll) in deg/s
    @Published var rotationY: Double = 0      // Rotation rate Y (pitch) in deg/s
    @Published var rotationZ: Double = 0      // Rotation rate Z (yaw) in deg/s
    @Published var fixStatus: Int = 0         // GNSS fix status (0: no fix, 2: 2D fix, 3: 3D fix)
    @Published var batteryLevel: Int = 0      // Battery level (0-100%)
    @Published var horizontalAccuracy: Double = 0 // Horizontal accuracy in meters
    
    // MARK: - Device identifiers
    @Published var deviceModel: String = ""   // e.g. "RaceBox Mini", "RaceBox Mini S", etc.
    @Published var firmwareVersion: String = ""
    
    // MARK: - Internal BLE references
    private var centralManager: CBCentralManager!
    private var raceBoxPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    
    // RaceBox UUIDs from documentation
    private let raceBoxServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let raceBoxRXCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let raceBoxTXCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // Device Information service UUIDs
    private let deviceInfoServiceUUID = CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB")
    private let modelNumberUUID = CBUUID(string: "00002A24-0000-1000-8000-00805F9B34FB")
    private let firmwareRevisionUUID = CBUUID(string: "00002A26-0000-1000-8000-00805F9B34FB")
    
    // Buffer for received data
    private var receiveBuffer = Data()
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// Begin scanning for the RaceBox device
    func startReadingData() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not powered on")
            return
        }
        print("Scanning for RaceBox devices...")
        
        // Scan for devices with names starting with "RaceBox Mini", "RaceBox Mini S", or "RaceBox Micro"
        centralManager.scanForPeripherals(withServices: [raceBoxServiceUUID], options: nil)
    }
    
    /// Stop scanning or disconnect if necessary
    func stopReadingData() {
        if let peripheral = raceBoxPeripheral, isConnected {
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
            print("RaceBoxManager: Bluetooth is powered on.")
        case .poweredOff:
            print("RaceBoxManager: Bluetooth is powered off.")
            isConnected = false
        case .resetting:
            print("RaceBoxManager: Bluetooth is resetting.")
        case .unauthorized:
            print("RaceBoxManager: Bluetooth is unauthorized.")
        case .unknown:
            print("RaceBoxManager: Bluetooth state unknown.")
        case .unsupported:
            print("RaceBoxManager: Bluetooth is unsupported on this device.")
        @unknown default:
            print("RaceBoxManager: Unknown Bluetooth state.")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        
        let peripheralName = peripheral.name ?? "Unknown"
        
        // Only connect to devices named "RaceBox Mini", "RaceBox Mini S", or "RaceBox Micro" followed by serial
        if peripheralName.starts(with: "RaceBox Mini ") ||
           peripheralName.starts(with: "RaceBox Mini S ") ||
           peripheralName.starts(with: "RaceBox Micro ") {
            
            print("Discovered RaceBox device: \(peripheralName), RSSI: \(RSSI)")
            
            // Save reference to the peripheral and connect
            raceBoxPeripheral = peripheral
            raceBoxPeripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
            centralManager.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("Connected to RaceBox peripheral: \(peripheral.name ?? "Unknown")")
        
        // Discover device information and UART service
        peripheral.discoverServices([deviceInfoServiceUUID, raceBoxServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("Failed to connect to RaceBox: \(error?.localizedDescription ?? "Unknown error")")
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("RaceBox disconnected: \(error?.localizedDescription ?? "No error")")
        isConnected = false
        
        // Clear characteristics
        txCharacteristic = nil
        rxCharacteristic = nil
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
            print("Discovered service: \(service.uuid)")
            
            if service.uuid == deviceInfoServiceUUID {
                // Discover device information characteristics
                peripheral.discoverCharacteristics(
                    [modelNumberUUID, firmwareRevisionUUID],
                    for: service
                )
            } else if service.uuid == raceBoxServiceUUID {
                // Discover UART characteristics
                peripheral.discoverCharacteristics(
                    [raceBoxRXCharacteristicUUID, raceBoxTXCharacteristicUUID],
                    for: service
                )
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
            print("Discovered characteristic: \(characteristic.uuid)")
            
            if characteristic.uuid == modelNumberUUID {
                // Read the model number
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == firmwareRevisionUUID {
                // Read the firmware revision
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == raceBoxTXCharacteristicUUID {
                // This is the characteristic the RaceBox uses to transmit data to us
                txCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribing to RaceBox TX notifications")
            } else if characteristic.uuid == raceBoxRXCharacteristicUUID {
                // This is the characteristic we use to send commands to the RaceBox
                rxCharacteristic = characteristic
            }
        }
        
        // If we found all required characteristics, mark as connected
        if txCharacteristic != nil && rxCharacteristic != nil {
            DispatchQueue.main.async {
                self.isConnected = true
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
        
        if characteristic.uuid == modelNumberUUID {
            // Parse model number
            if let modelString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.deviceModel = modelString
                    print("RaceBox Model: \(modelString)")
                }
            }
        } else if characteristic.uuid == firmwareRevisionUUID {
            // Parse firmware revision
            if let firmwareString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.firmwareVersion = firmwareString
                    print("RaceBox Firmware: \(firmwareString)")
                }
            }
        } else if characteristic.uuid == raceBoxTXCharacteristicUUID {
            // This is RaceBox data, add to buffer and process
            receiveBuffer.append(data)
            processReceiveBuffer()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error)")
        } else {
            print("Successfully wrote to characteristic")
        }
    }
}

// MARK: - Data Processing
extension RaceBoxManager {
    /// Process the receive buffer, extracting complete packets
    private func processReceiveBuffer() {
        // Look for packets starting with 0xB5 0x62 (header)
        while receiveBuffer.count >= 8 { // Minimum packet size: header(2) + class(1) + id(1) + length(2) + checksum(2)
            // Check for header
            if receiveBuffer[0] == 0xB5 && receiveBuffer[1] == 0x62 {
                // Extract message class, ID, and length
                let messageClass = receiveBuffer[2]
                let messageID = receiveBuffer[3]
                
                // Extract payload length (little-endian)
                let payloadLength = UInt16(receiveBuffer[4]) | (UInt16(receiveBuffer[5]) << 8)
                
                // Calculate total packet length
                let packetLength = 6 + Int(payloadLength) + 2 // header(2) + class(1) + id(1) + length(2) + payload + checksum(2)
                
                // Check if we have a complete packet
                if receiveBuffer.count >= packetLength {
                    // Extract the complete packet
                    let packet = receiveBuffer.subdata(in: 0..<packetLength)
                    
                    // Verify checksum
                    if verifyChecksum(packet: packet) {
                        // Process the packet based on class and ID
                        if messageClass == 0xFF && messageID == 0x01 {
                            // RaceBox Data Message
                            let payload = packet.subdata(in: 6..<(6 + Int(payloadLength)))
                            processRaceBoxDataMessage(payload)
                        }
                    } else {
                        print("Invalid checksum in RaceBox packet")
                    }
                    
                    // Remove the processed packet from the buffer
                    receiveBuffer.removeSubrange(0..<packetLength)
                } else {
                    // Not enough data yet, wait for more
                    break
                }
            } else {
                // Invalid header, remove first byte and try again
                receiveBuffer.removeFirst()
            }
        }
    }
    
    /// Verify the checksum of a packet
    private func verifyChecksum(packet: Data) -> Bool {
        guard packet.count >= 8 else { return false }
        
        // Last two bytes are the checksum
        let receivedCK_A = packet[packet.count - 2]
        let receivedCK_B = packet[packet.count - 1]
        
        // Calculate checksum
        var CK_A: UInt8 = 0
        var CK_B: UInt8 = 0
        
        // Checksum includes class, ID, length, and payload (but not header or checksum itself)
        for i in 2..<(packet.count - 2) {
            CK_A = CK_A &+ packet[i]
            CK_B = CK_B &+ CK_A
        }
        
        return (CK_A == receivedCK_A) && (CK_B == receivedCK_B)
    }
    
    /// Process the RaceBox Data Message (0xFF 0x01)
    private func processRaceBoxDataMessage(_ payload: Data) {
        guard payload.count >= 80 else {
            print("RaceBox data message too short: \(payload.count) bytes")
            return
        }
        
        // Extract fix status
        let fixStatusValue = payload[20]
        
        // Extract latitude and longitude
        let latitude = Int32(littleEndian: payload.subdata(in: 28..<32).withUnsafeBytes { $0.load(as: Int32.self) })
        let longitude = Int32(littleEndian: payload.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: Int32.self) })
        
        // Extract altitude (WGS)
        let altitude = Int32(littleEndian: payload.subdata(in: 32..<36).withUnsafeBytes { $0.load(as: Int32.self) })
        
        // Extract horizontal accuracy
        let hAcc = UInt32(littleEndian: payload.subdata(in: 40..<44).withUnsafeBytes { $0.load(as: UInt32.self) })
        
        // Extract speed
        let speed = Int32(littleEndian: payload.subdata(in: 48..<52).withUnsafeBytes { $0.load(as: Int32.self) })
        
        // Extract heading
        let heading = Int32(littleEndian: payload.subdata(in: 52..<56).withUnsafeBytes { $0.load(as: Int32.self) })
        
        // Extract G-forces
        let gForceX = Int16(littleEndian: payload.subdata(in: 68..<70).withUnsafeBytes { $0.load(as: Int16.self) })
        let gForceY = Int16(littleEndian: payload.subdata(in: 70..<72).withUnsafeBytes { $0.load(as: Int16.self) })
        let gForceZ = Int16(littleEndian: payload.subdata(in: 72..<74).withUnsafeBytes { $0.load(as: Int16.self) })
        
        // Extract rotation rates
        let rotationX = Int16(littleEndian: payload.subdata(in: 74..<76).withUnsafeBytes { $0.load(as: Int16.self) })
        let rotationY = Int16(littleEndian: payload.subdata(in: 76..<78).withUnsafeBytes { $0.load(as: Int16.self) })
        let rotationZ = Int16(littleEndian: payload.subdata(in: 78..<80).withUnsafeBytes { $0.load(as: Int16.self) })
        
        // Extract battery status - MSB is charging status, lower 7 bits are percentage (for Mini and Mini S)
        // For Micro, this is input voltage * 10
        let batteryStatus = payload[73]
        let batteryPercentage = Int(batteryStatus & 0x7F)  // Extract lower 7 bits
        
        // Convert values to proper units
        let latitudeDegrees = Double(latitude) / 10_000_000.0    // Convert to degrees
        let longitudeDegrees = Double(longitude) / 10_000_000.0  // Convert to degrees
        let altitudeMeters = Double(altitude) / 1000.0          // Convert to meters
        let horizontalAccuracyMeters = Double(hAcc) / 1000.0    // Convert to meters
        let speedMS = Double(speed) / 1000.0                    // Convert to m/s
        let headingDegrees = Double(heading) / 100_000.0        // Convert to degrees
        let gForceXValue = Double(gForceX) / 1000.0             // Convert to g
        let gForceYValue = Double(gForceY) / 1000.0             // Convert to g
        let gForceZValue = Double(gForceZ) / 1000.0             // Convert to g
        let rotationXDegS = Double(rotationX) / 100.0           // Convert to deg/s
        let rotationYDegS = Double(rotationY) / 100.0           // Convert to deg/s
        let rotationZDegS = Double(rotationZ) / 100.0           // Convert to deg/s
        
        // Update the published properties
        DispatchQueue.main.async {
            self.fixStatus = Int(fixStatusValue)
            self.latitude = latitudeDegrees
            self.longitude = longitudeDegrees
            self.altitude = altitudeMeters
            self.horizontalAccuracy = horizontalAccuracyMeters
            self.currentSpeed = speedMS
            self.heading = headingDegrees
            self.gForceX = gForceXValue
            self.gForceY = gForceYValue
            self.gForceZ = gForceZValue
            self.rotationX = rotationXDegS
            self.rotationY = rotationYDegS
            self.rotationZ = rotationZDegS
            self.batteryLevel = batteryPercentage
        }
    }
    
    /// Send a command to the RaceBox device
    func sendCommand(_ commandData: Data) {
        guard isConnected, let peripheral = raceBoxPeripheral, let rxCharacteristic = rxCharacteristic else {
            print("Cannot send command - not connected to RaceBox")
            return
        }
        
        peripheral.writeValue(commandData, for: rxCharacteristic, type: .withResponse)
    }
}

// MARK: - Helper Extensions
extension Data {
    /// Helper to initialize a UInt16 from two bytes in the data
    func readUInt16(offset: Int) -> UInt16 {
        return (UInt16(self[offset + 1]) << 8) | UInt16(self[offset])
    }
    
    /// Helper to initialize an Int32 from four bytes in the data
    func readInt32(offset: Int) -> Int32 {
        return Int32(UInt32(self[offset]) |
                    (UInt32(self[offset + 1]) << 8) |
                    (UInt32(self[offset + 2]) << 16) |
                    (UInt32(self[offset + 3]) << 24))
    }
}
