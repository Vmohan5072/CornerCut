//
//  OBDManager.swift
//  RaceBoxLapTimer
//

import Foundation
import CoreBluetooth
import Combine

class OBDManager: NSObject {
    
    // MARK: - Enums
    
    enum ConnectionState {
        case disconnected
        case scanning
        case connecting
        case initializing
        case connected
        case failed(Error)
    }
    
    enum OBDError: Error {
        case deviceNotFound
        case serviceNotFound
        case characteristicNotFound
        case notConnected
        case initializationFailed
        case noResponse
        case invalidResponse
        case timeout
        case unsupportedCommand
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var vehicleData = VehicleData()
    @Published private(set) var supportedParameters: [OBDParameter] = []
    @Published private(set) var latestResponses: [String: OBDResponse] = [:]
    @Published private(set) var isPolling: Bool = false
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var obdDevice: CBPeripheral?
    private var uartService: CBService?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    
    private var responseBuffer = ""
    private let bufferLock = NSLock()
    private var currentCommand: String = ""
    private var currentParameter: OBDParameter?
    private var commandQueue: [OBDParameter] = []
    private var responseTimer: Timer?
    private var pollingTimer: Timer?
    private var initializationComplete = false
    private var parameterSupportMap: [String: Bool] = [:]
    private var responseHandlers: [(String, (String) -> Void)] = []
    
    private let commandTimeout: TimeInterval = 3.0
    private let pollingInterval: TimeInterval = 0.1  // Start with a fast poll rate
    private let devicePrefix = "OBD"  // Common prefixes for OBD adapters
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionState = .failed(OBDError.deviceNotFound)
            return
        }
        
        connectionState = .scanning
        
        // Scan for all devices - most OBD adapters don't advertise specific services
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScanning() {
        if centralManager.isScanning {
            centralManager.stopScan()
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        
        obdDevice = peripheral
        obdDevice?.delegate = self
        
        connectionState = .connecting
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        stopPolling()
        
        if let peripheral = obdDevice, peripheral.state != .disconnected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        responseTimer?.invalidate()
        responseTimer = nil
        
        responseBuffer = ""
        currentCommand = ""
        currentParameter = nil
        commandQueue = []
        initializationComplete = false
        parameterSupportMap = [:]
        
        connectionState = .disconnected
    }
    
    func startPolling() {
        guard connectionState == .connected, initializationComplete else {
            return
        }
        
        isPolling = true
        
        // Start with the first poll right away
        pollNextParameter()
        
        // Setup a timer for continuous polling
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.pollNextParameter()
        }
    }
    
    func stopPolling() {
        isPolling = false
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // Request specific parameter value
    func requestParameter(_ parameter: OBDParameter, completion: ((OBDResponse?) -> Void)? = nil) {
        guard connectionState == .connected, initializationComplete else {
            completion?(nil)
            return
        }
        
        let command = OBDPacketDecoder.generateCommand(for: parameter)
        
        if let completion = completion {
            sendCommand(command) { [weak self] response in
                guard let self = self else { return }
                
                if let parsedResponse = OBDPacketDecoder.parseResponse(response, for: parameter) {
                    self.latestResponses[parameter.id] = parsedResponse
                    completion(parsedResponse)
                } else {
                    completion(nil)
                }
            }
        } else {
            // Add to poll queue instead
            if !commandQueue.contains(where: { $0.id == parameter.id }) {
                commandQueue.append(parameter)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initialize() {
        connectionState = .initializing
        let initCommands = OBDPacketDecoder.generateInitializationSequence()
        
        // Send each initialization command in sequence
        sendInitializationSequence(commands: initCommands, index: 0) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                // Now check which parameters are supported
                self.checkSupportedParameters {
                    self.initializationComplete = true
                    self.connectionState = .connected
                }
            } else {
                self.connectionState = .failed(OBDError.initializationFailed)
                self.disconnect()
            }
        }
    }
    
    private func sendInitializationSequence(commands: [String], index: Int, completion: @escaping (Bool) -> Void) {
        guard index < commands.count else {
            // All commands sent successfully
            completion(true)
            return
        }
        
        let command = commands[index]
        
        sendCommand(command) { [weak self] response in
            guard let self = self else { return }
            
            if OBDPacketDecoder.isAdapterReady(response) || response.contains("41") {
                // Command successful, send next command
                self.sendInitializationSequence(commands: commands, index: index + 1, completion: completion)
            } else {
                // Retry current command up to 3 times
                if index < 3 {
                    self.sendInitializationSequence(commands: commands, index: index, completion: completion)
                } else {
                    // Failed too many times
                    completion(false)
                }
            }
        }
    }
    
    private func checkSupportedParameters(completion: @escaping () -> Void) {
        // First check the basic support command (01 00) for mode 01 PIDs 01-20
        sendCommand("0100") { [weak self] response in
            guard let self = self else { return }
            
            if response.hasPrefix("41") {
                // Parse response to determine supported PIDs
                var supportedParams: [OBDParameter] = []
                
                for param in OBDPIDs.defaultParameters {
                    if param.mode == 0x01 {
                        if OBDPacketDecoder.isCommandSupported(response, command: param.id) {
                            self.parameterSupportMap[param.id] = true
                            supportedParams.append(param)
                        } else {
                            self.parameterSupportMap[param.id] = false
                        }
                    }
                }
                
                self.supportedParameters = supportedParams
                completion()
            } else {
                // Fall back to default parameters
                self.supportedParameters = OBDPIDs.defaultParameters
                completion()
            }
        }
    }
    
    private func pollNextParameter() {
        guard isPolling, !commandQueue.isEmpty, currentCommand.isEmpty else {
            return
        }
        
        // Find highest priority parameter that isn't currently being processed
        let sortedQueue = commandQueue.sorted { $0.priority < $1.priority }
        
        if let nextParam = sortedQueue.first {
            // Remove from queue
            commandQueue.removeAll { $0.id == nextParam.id }
            
            // Skip if not supported
            if let isSupported = parameterSupportMap[nextParam.id], !isSupported {
                // Immediately proceed to next parameter
                pollNextParameter()
                return
            }
            
            // Request the parameter
            currentParameter = nextParam
            let command = OBDPacketDecoder.generateCommand(for: nextParam)
            
            sendCommand(command) { [weak self] response in
                guard let self = self else { return }
                
                if let parsedResponse = OBDPacketDecoder.parseResponse(response, for: nextParam) {
                    self.latestResponses[nextParam.id] = parsedResponse
                    
                    // Update vehicle data
                    self.updateVehicleData(from: parsedResponse)
                }
                
                // Add parameter back to queue for next poll cycle
                self.commandQueue.append(nextParam)
            }
        }
    }
    
    private func updateVehicleData(from response: OBDResponse) {
        guard let value = response.value else { return }
        
        switch response.parameter.id {
        case OBDPIDs.rpm.id:
            vehicleData.rpm = value
        case OBDPIDs.speed.id:
            vehicleData.speed = value
        case OBDPIDs.throttlePosition.id:
            vehicleData.throttlePosition = value
        case OBDPIDs.engineLoad.id:
            vehicleData.engineLoad = value
        case OBDPIDs.coolantTemp.id:
            vehicleData.coolantTemp = value
        case OBDPIDs.oilTemp.id:
            vehicleData.oilTemp = value
        case OBDPIDs.boost.id:
            vehicleData.boostPressure = value
        default:
            break
        }
        
        // Derive gear based on RPM and speed
        vehicleData.deriveGear()
        
        // Clean up extreme values
        vehicleData.sanitize()
    }
    
    private func sendCommand(_ command: String, completion: @escaping (String) -> Void) {
        guard let peripheral = obdDevice, peripheral.state == .connected else {
            completion("")
            return
        }
        
        guard let rxChar = rxCharacteristic else {
            completion("")
            return
        }
        
        // Store completion handler
        responseHandlers.append((command, completion))
        
        // Clear buffer before sending new command
        bufferLock.lock()
        responseBuffer = ""
        bufferLock.unlock()
        
        // Format command properly for ELM327
        let finalCommand = OBDPacketDecoder.finalizeCommand(command)
        currentCommand = command
        
        // Set a timeout
        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Command timed out, remove and process next
            if !self.currentCommand.isEmpty {
                self.processCommandResponse("")
            }
        }
        
        // Send the command
        if let data = finalCommand.data(using: .ascii) {
            peripheral.writeValue(data, for: rxChar, type: .withResponse)
        }
    }
    
    private func processCommandResponse(_ additionalData: String) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Add new data to buffer
        if !additionalData.isEmpty {
            responseBuffer += additionalData
        }
        
        // Check if we have a complete response (ends with prompt or contains expected data)
        let response = responseBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let isComplete = response.contains(OBDPacketDecoder.ELM_PROMPT) ||
                         response.contains(OBDPacketDecoder.ELM_ERROR) ||
                         response.contains(OBDPacketDecoder.ELM_NO_DATA) ||
                         (currentCommand.hasPrefix("01") && response.hasPrefix("41")) ||
                         (currentCommand.hasPrefix("09") && response.hasPrefix("49"))
        
        if isComplete || additionalData.isEmpty {
            responseTimer?.invalidate()
            responseTimer = nil
            
            // Find and call the matching response handler
            if let index = responseHandlers.firstIndex(where: { $0.0 == currentCommand }) {
                let handler = responseHandlers.remove(at: index)
                handler.1(response)
            }
            
            // Reset for next command
            currentCommand = ""
            currentParameter = nil
            responseBuffer = ""
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension OBDManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Ready to use
            break
        case .poweredOff:
            connectionState = .disconnected
        default:
            connectionState = .failed(OBDError.deviceNotFound)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Look for OBD-II adapters
        if let name = peripheral.name, name.hasPrefix(devicePrefix) || name.hasPrefix("ELM") {
            connect(to: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Discover services
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .failed(error ?? OBDError.deviceNotFound)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        disconnect()
    }
}

// MARK: - CBPeripheralDelegate
extension OBDManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            connectionState = .failed(error!)
            return
        }
        
        guard let services = peripheral.services else { return }
        
        // Look for a serial/UART service
        for service in services {
            // Common UART service UUIDs
            let uartUUIDs = [
                            "FFE0",  // Common for HC-05/HC-06 modules
                            "1101",  // SPP UUID
                            "FFF0"   // Another common OBD adapter UUID
                        ]
                        
                        if uartUUIDs.contains(where: { service.uuid.uuidString.contains($0) }) ||
                           service.uuid.uuidString.contains("FF") { // Many custom UART services contain FF
                            uartService = service
                            peripheral.discoverCharacteristics(nil, for: service)
                        }
                    }
                    
                    if uartService == nil {
                        // If we haven't found a specific UART service, try to discover characteristics for all services
                        for service in services {
                            peripheral.discoverCharacteristics(nil, for: service)
                        }
                    }
                }
                
                func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
                    guard error == nil else {
                        connectionState = .failed(error!)
                        return
                    }
                    
                    guard let characteristics = service.characteristics else { return }
                    
                    // Look for TX and RX characteristics (could be named differently based on OBD adapter)
                    for characteristic in characteristics {
                        // Check properties to identify TX (notify) and RX (write) characteristics
                        if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                            // This is likely the TX characteristic (device -> phone)
                            txCharacteristic = characteristic
                            peripheral.setNotifyValue(true, for: characteristic)
                        }
                        
                        if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                            // This is likely the RX characteristic (phone -> device)
                            rxCharacteristic = characteristic
                        }
                    }
                    
                    // Start initialization if we have the required characteristics
                    if txCharacteristic != nil && rxCharacteristic != nil {
                        initialize()
                    } else {
                        connectionState = .failed(OBDError.characteristicNotFound)
                    }
                }
                
                func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
                    guard error == nil else { return }
                    
                    // Process received data
                    if characteristic.uuid == txCharacteristic?.uuid, let data = characteristic.value {
                        if let response = String(data: data, encoding: .ascii) {
                            processCommandResponse(response)
                        }
                    }
                }
                
                func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
                    if let error = error {
                        print("Error writing to characteristic: \(error.localizedDescription)")
                    }
                }
                
                func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
                    if let error = error {
                        print("Error changing notification state: \(error.localizedDescription)")
                    }
                }
            }
