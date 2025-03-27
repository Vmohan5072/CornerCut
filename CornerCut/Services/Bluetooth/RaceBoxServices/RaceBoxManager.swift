//
//  RaceBoxManager.swift
//  RaceBoxLapTimer
//
//  Created for RaceBox Lap Timer App
//

import Foundation
import CoreBluetooth
import Combine

class RaceBoxManager: NSObject {
    
    // MARK: - Enums
    
    enum ConnectionState {
        case disconnected
        case scanning
        case connecting
        case connected
        case failed(Error)
    }
    
    enum RaceBoxError: Error {
        case deviceNotFound
        case serviceNotFound
        case characteristicNotFound
        case notConnected
        case invalidPacket
        case operationFailed
        case memoryLocked
        case memoryOperationInProgress
        case unsupportedFeature
        case timeout
    }
    
    // MARK: - Properties
    
    // Public properties
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var deviceInfo: RaceBoxDeviceInfo?
    @Published private(set) var latestData: RaceBoxData?
    @Published private(set) var recordingStatus: RaceBoxRecordingStatus?
    @Published private(set) var platformConfig: RaceBoxPlatformConfig?
    @Published private(set) var isPerformingMemoryOperation = false
    
    // Bluetooth properties
    private var centralManager: CBCentralManager!
    private var raceBoxDevice: CBPeripheral?
    private var uartService: CBService?
    private var uartTXCharacteristic: CBCharacteristic?
    private var uartRXCharacteristic: CBCharacteristic?
    private var nmeaService: CBService?
    private var nmeaTXCharacteristic: CBCharacteristic?
    
    // Private properties
    private var packetBuffer = Data()
    private let packetBufferLock = NSLock()
    private var deviceInfoCompletionHandlers: [() -> Void] = []
    private var operationCompletionHandlers: [(Result<Data, RaceBoxError>) -> Void] = []
    private var packetAccumulationTimer: Timer?
    private var connectionTimeout: Timer?
    
    // Settings
    private var scanTimeout: TimeInterval = 15.0
    private var connectionTimeoutInterval: TimeInterval = 10.0
    private var packetWaitTimeout: TimeInterval = 0.1
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Scanning and Connection
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionState = .failed(RaceBoxError.deviceNotFound)
            return
        }
        
        connectionState = .scanning
        
        // Set up a timeout for scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + scanTimeout) { [weak self] in
            guard let self = self, case .scanning = self.connectionState else { return }
            self.stopScanning()
            self.connectionState = .failed(RaceBoxError.deviceNotFound)
        }
        
        // Start scanning for RaceBox devices
        let uartServiceUUID = CBUUID(string: RaceBoxProtocol.uartServiceUUID)
        centralManager.scanForPeripherals(withServices: [uartServiceUUID], options: nil)
    }
    
    func stopScanning() {
        guard centralManager.isScanning else { return }
        centralManager.stopScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        
        raceBoxDevice = peripheral
        raceBoxDevice?.delegate = self
        
        connectionState = .connecting
        
        // Set connection timeout
        connectionTimeout = Timer.scheduledTimer(withTimeInterval: connectionTimeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self, case .connecting = self.connectionState else { return }
            self.disconnect()
            self.connectionState = .failed(RaceBoxError.timeout)
        }
        
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = raceBoxDevice, peripheral.state != .disconnected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        
        // Reset connection properties
        uartService = nil
        uartTXCharacteristic = nil
        uartRXCharacteristic = nil
        nmeaService = nil
        nmeaTXCharacteristic = nil
        deviceInfo = nil
        latestData = nil
        recordingStatus = nil
        platformConfig = nil
        
        // Clear operations
        packetBuffer.removeAll()
        operationCompletionHandlers.removeAll()
        deviceInfoCompletionHandlers.removeAll()
        isPerformingMemoryOperation = false
        
        connectionState = .disconnected
    }
    
    // MARK: - Device Info
    
    func readDeviceInfo(completion: (() -> Void)? = nil) {
        guard let peripheral = raceBoxDevice, peripheral.state == .connected else {
            completion?()
            return
        }
        
        if let completion = completion {
            deviceInfoCompletionHandlers.append(completion)
        }
        
        let deviceInfoServiceUUID = CBUUID(string: RaceBoxProtocol.deviceInfoServiceUUID)
        
        // Check if we've already discovered the Device Info service
        if let services = peripheral.services, let service = services.first(where: { $0.uuid == deviceInfoServiceUUID }) {
            peripheral.discoverCharacteristics(nil, for: service)
        } else {
            peripheral.discoverServices([deviceInfoServiceUUID])
        }
    }
    
    // MARK: - Device Configuration
    
    func readPlatformConfig(completion: ((Result<RaceBoxPlatformConfig, RaceBoxError>) -> Void)? = nil) {
        guard deviceInfo?.supportsPlatformConfig == true else {
            completion?(.failure(.unsupportedFeature))
            return
        }
        
        let packet = Data(bytes: RaceBoxProtocol.packetStartBytes + [RaceBoxProtocol.MessageClass.ubx.rawValue, RaceBoxProtocol.MessageID.platformConfig.rawValue, 0x00, 0x00] + [0x26, 0x27]) // Last 2 bytes are checksum
        
        sendCommand(packet) { [weak self] result in
            switch result {
            case .success(let data):
                if data.count >= 8 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.platformConfig.rawValue {
                    var config = RaceBoxPlatformConfig()
                    config.platformModel = RaceBoxPlatformConfig.DynamicPlatformModel(rawValue: data[6]) ?? .automotive
                    config.enable3DSpeed = data[7] != 0
                    config.minHorizontalAccuracy = data[8]
                    
                    self?.platformConfig = config
                    completion?(.success(config))
                } else {
                    completion?(.failure(.invalidPacket))
                }
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    func setPlatformConfig(_ config: RaceBoxPlatformConfig, completion: ((Result<Void, RaceBoxError>) -> Void)? = nil) {
            guard deviceInfo?.supportsPlatformConfig == true else {
                completion?(.failure(.unsupportedFeature))
                return
            }
            
            let packet = RaceBoxPacketDecoder.createPlatformConfigPacket(config: config)
            
            sendCommand(packet) { result in
                switch result {
                case .success(let data):
                    if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.ack.rawValue {
                        completion?(.success(()))
                    } else if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.nack.rawValue {
                        completion?(.failure(.operationFailed))
                    } else {
                        completion?(.failure(.invalidPacket))
                    }
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
        
        // MARK: - Recording Management
        
        func getRecordingStatus(completion: ((Result<RaceBoxRecordingStatus, RaceBoxError>) -> Void)? = nil) {
            guard deviceInfo?.supportsRecording == true else {
                completion?(.failure(.unsupportedFeature))
                return
            }
            
            let packet = Data(bytes: RaceBoxProtocol.packetStartBytes + [RaceBoxProtocol.MessageClass.ubx.rawValue, RaceBoxProtocol.MessageID.recordingStatus.rawValue, 0x00, 0x00] + [0x21, 0x65]) // Last 2 bytes are checksum
            
            sendCommand(packet) { [weak self] result in
                switch result {
                case .success(let data):
                    if data.count >= 18 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.recordingStatus.rawValue {
                        if let recordingStatus = RaceBoxPacketDecoder.parseRecordingStatus(data: data.dropFirst(6).prefix(12)) {
                            self?.recordingStatus = recordingStatus
                            completion?(.success(recordingStatus))
                        } else {
                            completion?(.failure(.invalidPacket))
                        }
                    } else {
                        completion?(.failure(.invalidPacket))
                    }
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
        
        func startRecording(dataRate: UInt8 = 0, enableStationaryFilter: Bool = true, enableNoFixFilter: Bool = true, enableAutoShutdown: Bool = true, waitForData: Bool = true, stationaryThreshold: UInt16 = 1389, stationaryInterval: UInt16 = 30, noFixInterval: UInt16 = 30, shutdownInterval: UInt16 = 300, completion: ((Result<Void, RaceBoxError>) -> Void)? = nil) {
            
            guard deviceInfo?.supportsRecording == true else {
                completion?(.failure(.unsupportedFeature))
                return
            }
            
            // Check if memory is locked
            if let status = recordingStatus, status.isMemorySecurityEnabled && !status.isMemoryUnlocked {
                completion?(.failure(.memoryLocked))
                return
            }
            
            let packet = RaceBoxPacketDecoder.createRecordingConfigPacket(
                enable: true,
                dataRate: dataRate,
                stationary: enableStationaryFilter,
                noFix: enableNoFixFilter,
                autoShutdown: enableAutoShutdown,
                waitForData: waitForData,
                stationaryThreshold: stationaryThreshold,
                stationaryInterval: stationaryInterval,
                noFixInterval: noFixInterval,
                shutdownInterval: shutdownInterval
            )
            
            sendCommand(packet) { result in
                switch result {
                case .success(let data):
                    if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.ack.rawValue {
                        completion?(.success(()))
                    } else if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.nack.rawValue {
                        completion?(.failure(.operationFailed))
                    } else {
                        completion?(.failure(.invalidPacket))
                    }
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
        
        func stopRecording(completion: ((Result<Void, RaceBoxError>) -> Void)? = nil) {
            guard deviceInfo?.supportsRecording == true else {
                completion?(.failure(.unsupportedFeature))
                return
            }
            
            // Check if memory is locked
            if let status = recordingStatus, status.isMemorySecurityEnabled && !status.isMemoryUnlocked {
                completion?(.failure(.memoryLocked))
                return
            }
            
            let packet = RaceBoxPacketDecoder.createRecordingConfigPacket(enable: false, dataRate: 0)
            
            sendCommand(packet) { result in
                switch result {
                case .success(let data):
                    if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.ack.rawValue {
                        completion?(.success(()))
                    } else if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.nack.rawValue {
                        completion?(.failure(.operationFailed))
                    } else {
                        completion?(.failure(.invalidPacket))
                    }
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
        
        // MARK: - Memory Operations
        
        func unlockMemory(securityCode: UInt32, completion: ((Result<Void, RaceBoxError>) -> Void)? = nil) {
            guard deviceInfo?.supportsRecording == true else {
                completion?(.failure(.unsupportedFeature))
                return
            }
            
            let packet = RaceBoxPacketDecoder.createMemoryUnlockPacket(securityCode: securityCode)
            
            sendCommand(packet) { result in
                switch result {
                case .success(let data):
                    if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.ack.rawValue {
                        completion?(.success(()))
                    } else if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[3] == RaceBoxProtocol.MessageID.nack.rawValue {
                        completion?(.failure(.operationFailed))
                    } else {
                        completion?(.failure(.invalidPacket))
                    }
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
        
        func downloadRecordedData(progress: ((Double) -> Void)? = nil, completion: ((Result<[RaceBoxData], RaceBoxError>) -> Void)? = nil) {
            guard deviceInfo?.supportsRecording == true else {
                completion?(.failure(.unsupportedFeature))
                return
            }
            
            // Check if memory is locked
            if let status = recordingStatus, status.isMemorySecurityEnabled && !status.isMemoryUnlocked {
                completion?(.failure(.memoryLocked))
                return
            }
            
            // Check if another memory operation is in progress
            if isPerformingMemoryOperation {
                completion?(.failure(.memoryOperationInProgress))
                return
            }
            
            isPerformingMemoryOperation = true
            
            let packet = RaceBoxPacketDecoder.createDataDownloadPacket()
            
            var historyData: [RaceBoxData] = []
            var expectedCount: UInt32 = 0
            var receivedCount: UInt32 = 0
            
            // Set up data packet handler
            let dataHandler: (Data) -> Bool = { [weak self] data in
                // Process history data or ACK/NACK packets
                if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue {
                    if data[3] == RaceBoxProtocol.MessageID.dataDownload.rawValue && data.count >= 10 {
                        // Initial response with expected count
                        expectedCount = data.extract(UInt32.self, fromOffset: 6)
                        return false // Continue receiving
                    } else if data[3] == RaceBoxProtocol.MessageID.historyDataMessage.rawValue && data.count >= 86 {
                        // History data packet
                        if let historyPoint = RaceBoxPacketDecoder.parseDataMessage(data: data.dropFirst(6).prefix(80)) {
                            historyData.append(historyPoint)
                            receivedCount += 1
                            progress?(Double(receivedCount) / Double(expectedCount))
                        }
                        return false // Continue receiving
                    } else if data[3] == RaceBoxProtocol.MessageID.ack.rawValue && data[6] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[7] == RaceBoxProtocol.MessageID.dataDownload.rawValue {
                        // Download complete
                        self?.isPerformingMemoryOperation = false
                        completion?(.success(historyData))
                        return true // Operation complete
                    } else if data[3] == RaceBoxProtocol.MessageID.nack.rawValue {
                        // Operation failed
                        self?.isPerformingMemoryOperation = false
                        completion?(.failure(.operationFailed))
                        return true // Operation complete
                    }
                }
                return false // Continue receiving
            }
            
            // Start the download
            sendCommand(packet, dataHandler: dataHandler) { result in
                switch result {
                case .success(_):
                    // Handled by dataHandler
                    break
                case .failure(let error):
                    self.isPerformingMemoryOperation = false
                    completion?(.failure(error))
                }
            }
        }
        
        func eraseRecordedData(progress: ((Double) -> Void)? = nil, completion: ((Result<Void, RaceBoxError>) -> Void)? = nil) {
            guard deviceInfo?.supportsRecording == true else {
                completion?(.failure(.unsupportedFeature))
                return
            }
            
            // Check if memory is locked
            if let status = recordingStatus, status.isMemorySecurityEnabled && !status.isMemoryUnlocked {
                completion?(.failure(.memoryLocked))
                return
            }
            
            // Check if another memory operation is in progress
            if isPerformingMemoryOperation {
                completion?(.failure(.memoryOperationInProgress))
                return
            }
            
            isPerformingMemoryOperation = true
            
            let packet = RaceBoxPacketDecoder.createDataErasePacket()
            
            // Set up erase progress handler
            let dataHandler: (Data) -> Bool = { [weak self] data in
                if data.count >= 4 && data[2] == RaceBoxProtocol.MessageClass.ubx.rawValue {
                    if data[3] == RaceBoxProtocol.MessageID.dataErase.rawValue && data.count >= 7 {
                        // Erase progress notification
                        let eraseProgress = Double(data[6]) / 100.0
                        progress?(eraseProgress)
                        return false // Continue receiving
                    } else if data[3] == RaceBoxProtocol.MessageID.ack.rawValue && data[6] == RaceBoxProtocol.MessageClass.ubx.rawValue && data[7] == RaceBoxProtocol.MessageID.dataErase.rawValue {
                        // Erase complete
                        self?.isPerformingMemoryOperation = false
                        completion?(.success(()))
                        return true // Operation complete
                    } else if data[3] == RaceBoxProtocol.MessageID.nack.rawValue {
                        // Operation failed
                        self?.isPerformingMemoryOperation = false
                        completion?(.failure(.operationFailed))
                        return true // Operation complete
                    }
                }
                return false // Continue receiving
            }
            
            // Start the erase
            sendCommand(packet, dataHandler: dataHandler) { result in
                switch result {
                case .success(_):
                    // Handled by dataHandler
                    break
                case .failure(let error):
                    self.isPerformingMemoryOperation = false
                    completion?(.failure(error))
                }
            }
        }
        
        // MARK: - Command Sending
        
        private func sendCommand(_ packet: Data, dataHandler: ((Data) -> Bool)? = nil, completion: ((Result<Data, RaceBoxError>) -> Void)? = nil) {
            guard let peripheral = raceBoxDevice, peripheral.state == .connected else {
                completion?(.failure(.notConnected))
                return
            }
            
            guard let rxCharacteristic = uartRXCharacteristic else {
                completion?(.failure(.characteristicNotFound))
                return
            }
            
            // Add completion handler if provided
            if let completion = completion {
                operationCompletionHandlers.append(completion)
            }
            
            // Store data handler for continuous operations
            if let dataHandler = dataHandler {
                self.currentDataHandler = dataHandler
            }
            
            // Clear the packet buffer before sending new command
            packetBufferLock.lock()
            packetBuffer.removeAll()
            packetBufferLock.unlock()
            
            // Write the packet to the RX characteristic
            peripheral.writeValue(packet, for: rxCharacteristic, type: .withResponse)
        }
        
        // MARK: - Packet Handling
        
        private var currentDataHandler: ((Data) -> Bool)?
        
        private func processReceivedData(_ data: Data) {
            packetBufferLock.lock()
            defer { packetBufferLock.unlock() }
            
            // Append data to buffer
            packetBuffer.append(data)
            
            // Reset timer
            packetAccumulationTimer?.invalidate()
            packetAccumulationTimer = Timer.scheduledTimer(withTimeInterval: packetWaitTimeout, repeats: false) { [weak self] _ in
                self?.processPackets()
            }
        }
        
        private func processPackets() {
            packetBufferLock.lock()
            defer { packetBufferLock.unlock() }
            
            guard packetBuffer.count >= 8 else { return } // Minimum packet size: header (2) + class/id (2) + length (2) + checksum (2)
            
            var index = 0
            
            while index < packetBuffer.count - 7 { // -7 to ensure we have at least one complete packet
                // Find packet start
                if packetBuffer[index] == RaceBoxProtocol.packetStartBytes[0] && packetBuffer[index + 1] == RaceBoxProtocol.packetStartBytes[1] {
                    // Extract payload length
                    let payloadLength = UInt16(packetBuffer[index + 4]) | (UInt16(packetBuffer[index + 5]) << 8)
                    
                    // Calculate full packet length
                    let packetLength = 6 + Int(payloadLength) + 2 // header (2) + class/id (2) + length (2) + payload + checksum (2)
                    
                    // Check if we have the complete packet
                    if index + packetLength <= packetBuffer.count {
                        let packet = packetBuffer.subdata(in: index..<(index + packetLength))
                        
                        // Verify checksum
                        if RaceBoxPacketDecoder.verifyChecksum(packet: packet) {
                            handlePacket(packet)
                        }
                        
                        // Move index past this packet
                        index += packetLength
                    } else {
                        // Incomplete packet, wait for more data
                        break
                    }
                } else {
                    // Not a packet start, move forward
                    index += 1
                }
            }
            
            // Remove processed data from buffer
            if index > 0 {
                packetBuffer.removeSubrange(0..<index)
            }
        }
        
        private func handlePacket(_ packet: Data) {
            // Check if this is a response for a specific operation
            if let handler = currentDataHandler, handler(packet) {
                // If handler returns true, operation is complete
                currentDataHandler = nil
            }
            
            // Handle regular data packets
            if packet.count >= 4 {
                let messageClass = packet[2]
                let messageId = packet[3]
                
                if messageClass == RaceBoxProtocol.MessageClass.ubx.rawValue {
                    switch messageId {
                    case RaceBoxProtocol.MessageID.dataMessage.rawValue:
                        if packet.count >= 86 { // 6 byte header + 80 byte payload
                            if let data = RaceBoxPacketDecoder.parseDataMessage(data: packet.dropFirst(6).prefix(80)) {
                                DispatchQueue.main.async {
                                    self.latestData = data
                                }
                            }
                        }
                        
                    case RaceBoxProtocol.MessageID.recordingStatus.rawValue:
                        if packet.count >= 18 { // 6 byte header + 12 byte payload
                            if let status = RaceBoxPacketDecoder.parseRecordingStatus(data: packet.dropFirst(6).prefix(12)) {
                                DispatchQueue.main.async {
                                    self.recordingStatus = status
                                }
                            }
                        }
                        
                    case RaceBoxProtocol.MessageID.ack.rawValue, RaceBoxProtocol.MessageID.nack.rawValue:
                        // Handle ACK/NACK for operations
                        if !operationCompletionHandlers.isEmpty {
                            let handler = operationCompletionHandlers.removeFirst()
                            handler(.success(packet))
                        }
                        
                    default:
                        // Just pass the packet to completion handler if there is one
                        if !operationCompletionHandlers.isEmpty {
                            let handler = operationCompletionHandlers.removeFirst()
                            handler(.success(packet))
                        }
                    }
                }
            }
        }
    }

    // MARK: - CBCentralManagerDelegate
    extension RaceBoxManager: CBCentralManagerDelegate {
        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            switch central.state {
            case .poweredOn:
                // Ready to use
                break
            case .poweredOff:
                connectionState = .disconnected
            default:
                connectionState = .failed(RaceBoxError.deviceNotFound)
            }
        }
        
        func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
            // Check if the device name is in the expected format
            if let name = peripheral.name,
               (name.hasPrefix("RaceBox Mini ") || name.hasPrefix("RaceBox Mini S ") || name.hasPrefix("RaceBox Micro ")) {
                // Found a RaceBox device
                connect(to: peripheral)
            }
        }
        
        func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
            connectionTimeout?.invalidate()
            connectionTimeout = nil
            
            // Update connection state
            connectionState = .connected
            
            // Discover required services
            let uartServiceUUID = CBUUID(string: RaceBoxProtocol.uartServiceUUID)
            let deviceInfoServiceUUID = CBUUID(string: RaceBoxProtocol.deviceInfoServiceUUID)
            peripheral.discoverServices([uartServiceUUID, deviceInfoServiceUUID])
        }
        
        func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
            connectionTimeout?.invalidate()
            connectionTimeout = nil
            
            connectionState = .failed(error ?? RaceBoxError.deviceNotFound)
        }
        
        func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
            disconnect()
        }
    }

    // MARK: - CBPeripheralDelegate
    extension RaceBoxManager: CBPeripheralDelegate {
        func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
            if let error = error {
                connectionState = .failed(error)
                return
            }
            
            guard let services = peripheral.services else { return }
            
            for service in services {
                switch service.uuid.uuidString {
                case RaceBoxProtocol.uartServiceUUID:
                    uartService = service
                    let rxUUID = CBUUID(string: RaceBoxProtocol.uartRXCharUUID)
                    let txUUID = CBUUID(string: RaceBoxProtocol.uartTXCharUUID)
                    peripheral.discoverCharacteristics([rxUUID, txUUID], for: service)
                    
                case RaceBoxProtocol.deviceInfoServiceUUID:
                    let modelUUID = CBUUID(string: RaceBoxProtocol.modelCharUUID)
                    let serialNumberUUID = CBUUID(string: RaceBoxProtocol.serialNumberCharUUID)
                    let firmwareRevisionUUID = CBUUID(string: RaceBoxProtocol.firmwareRevisionCharUUID)
                    let hardwareRevisionUUID = CBUUID(string: RaceBoxProtocol.hardwareRevisionCharUUID)
                    let manufacturerUUID = CBUUID(string: RaceBoxProtocol.manufacturerCharUUID)
                    
                    peripheral.discoverCharacteristics([modelUUID, serialNumberUUID, firmwareRevisionUUID, hardwareRevisionUUID, manufacturerUUID], for: service)
                    
                case RaceBoxProtocol.nmeaServiceUUID:
                    nmeaService = service
                    let txUUID = CBUUID(string: RaceBoxProtocol.nmeaTXCharUUID)
                    peripheral.discoverCharacteristics([txUUID], for: service)
                    
                default:
                    break
                }
            }
        }
        
        func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
            if let error = error {
                connectionState = .failed(error)
                return
            }
            
            guard let characteristics = service.characteristics else { return }
            
            for characteristic in characteristics {
                switch characteristic.uuid.uuidString {
                case RaceBoxProtocol.uartRXCharUUID:
                    uartRXCharacteristic = characteristic
                    
                case RaceBoxProtocol.uartTXCharUUID:
                    uartTXCharacteristic = characteristic
                    // Enable notifications for data
                    peripheral.setNotifyValue(true, for: characteristic)
                    
                case RaceBoxProtocol.nmeaTXCharUUID:
                    nmeaTXCharacteristic = characteristic
                    // Only enable NMEA notifications if needed
                    if deviceInfo?.supportsNMEA == true {
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                    
                case RaceBoxProtocol.modelCharUUID,
                     RaceBoxProtocol.serialNumberCharUUID,
                     RaceBoxProtocol.firmwareRevisionCharUUID,
                     RaceBoxProtocol.hardwareRevisionCharUUID,
                     RaceBoxProtocol.manufacturerCharUUID:
                    // Read device info characteristics
                    peripheral.readValue(for: characteristic)
                    
                default:
                    break
                }
            }
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                print("Error updating characteristic value: \(error.localizedDescription)")
                return
            }
            
            guard let data = characteristic.value else { return }
            
            switch characteristic.uuid.uuidString {
            case RaceBoxProtocol.uartTXCharUUID:
                // Process received data packets
                processReceivedData(data)
                
            case RaceBoxProtocol.nmeaTXCharUUID:
                // Process NMEA data if needed
                break
                
            case RaceBoxProtocol.modelCharUUID:
                if let stringValue = String(data: data, encoding: .utf8) {
                    deviceInfo = deviceInfo ?? RaceBoxDeviceInfo()
                    deviceInfo?.model = stringValue
                    checkDeviceInfoComplete()
                }
                
            case RaceBoxProtocol.serialNumberCharUUID:
                if let stringValue = String(data: data, encoding: .utf8) {
                    deviceInfo = deviceInfo ?? RaceBoxDeviceInfo()
                    deviceInfo?.serialNumber = stringValue
                    checkDeviceInfoComplete()
                }
                
            case RaceBoxProtocol.firmwareRevisionCharUUID:
                if let stringValue = String(data: data, encoding: .utf8) {
                    deviceInfo = deviceInfo ?? RaceBoxDeviceInfo()
                    deviceInfo?.firmwareRevision = stringValue
                    checkDeviceInfoComplete()
                }
                
            case RaceBoxProtocol.hardwareRevisionCharUUID:
                if let stringValue = String(data: data, encoding: .utf8) {
                    deviceInfo = deviceInfo ?? RaceBoxDeviceInfo()
                    deviceInfo?.hardwareRevision = stringValue
                    checkDeviceInfoComplete()
                }
                
            case RaceBoxProtocol.manufacturerCharUUID:
                if let stringValue = String(data: data, encoding: .utf8) {
                    deviceInfo = deviceInfo ?? RaceBoxDeviceInfo()
                    deviceInfo?.manufacturer = stringValue
                    checkDeviceInfoComplete()
                }
                
            default:
                break
            }
        }
        
        private func checkDeviceInfoComplete() {
            guard let deviceInfo = deviceInfo else { return }
            
            // Check if we have all required info
            if !deviceInfo.model.isEmpty &&
               !deviceInfo.serialNumber.isEmpty &&
               !deviceInfo.firmwareRevision.isEmpty {
                
                // Check if NMEA service is supported
                if deviceInfo.supportsNMEA, let nmeaService = nmeaService, let nmeaTXCharacteristic = nmeaTXCharacteristic {
                    peripheral?.setNotifyValue(true, for: nmeaTXCharacteristic)
                }
                
                // Notify completion
                if !deviceInfoCompletionHandlers.isEmpty {
                    let handlers = deviceInfoCompletionHandlers
                    deviceInfoCompletionHandlers.removeAll()
                    
                    DispatchQueue.main.async {
                        handlers.forEach { $0() }
                    }
                }
            }
        }
        
        func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                if !operationCompletionHandlers.isEmpty {
                    let handler = operationCompletionHandlers.removeFirst()
                    handler(.failure(.operationFailed))
                }
                print("Error writing to characteristic: \(error.localizedDescription)")
            }
        }
        
        func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
            if let error = error {
                print("Error changing notification state: \(error.localizedDescription)")
            }
        }
    }
