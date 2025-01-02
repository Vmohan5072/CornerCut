import Foundation
import CoreBluetooth
import Combine

final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager() // Singleton instance

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var obdServiceUUID = CBUUID(string: "FFF0") // Example UUID
    private var obdCharacteristicUUID = CBUUID(string: "FFF1") // Example UUID
    private var obdCharacteristic: CBCharacteristic?

    @Published var isConnected: Bool = false
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScan() {
        print("Scanning for OBD2 devices...")
        centralManager.scanForPeripherals(withServices: [obdServiceUUID], options: nil)
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
    
    func sendCommand(_ command: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = obdCharacteristic,
              let data = command.data(using: .utf8) else { return }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
        default:
            print("Bluetooth not ready.")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
        centralManager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        isConnected = true
        peripheral.discoverServices([obdServiceUUID])
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == obdServiceUUID {
            peripheral.discoverCharacteristics([obdCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == obdCharacteristicUUID {
            obdCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        OBD2Manager.shared.parseOBDResponse(data)
    }
}
