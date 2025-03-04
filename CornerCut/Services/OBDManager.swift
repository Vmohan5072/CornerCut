import Foundation
import Combine
import SwiftUI

final class OBD2Manager: ObservableObject {
    static let shared = OBD2Manager() // Singleton instance

    // MARK: - Published Properties
    @Published var currentSpeed: Double = 0 // Speed (in user-selected unit)
    @Published var currentRPM: Double = 0 // Engine RPM
    @Published var throttle: Double = 0 // Throttle Position (%)
    @Published var oilTemperature: Double = 0 // Oil Temperature
    @Published var engineTemperature: Double = 0 // Engine Coolant Temperature
    @Published var intakeTemperature: Double = 0 // Intake Air Temperature
    @Published var fuelLevel: Double = 0 // Fuel Level (%)
    @Published var boostPressure: Double = 0 // Boost/MAP Pressure
    @Published var isDeviceConnected: Bool = false // Connection status
    @Published var availablePIDs: [String: Bool] = [:] // Available PIDs
    @Published var dtcCodes: [String] = [] // Diagnostic Trouble Codes

    // MARK: - User Settings
    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false // User's unit preference
    @AppStorage("preferredOBDDevice") private var preferredOBDDevice: String = "" // MAC address of preferred OBD device
    @AppStorage("pollFrequency") private var pollFrequency: Double = 1.0 // How often to poll OBD data (in seconds)

    // MARK: - Internal Properties
    private var bluetoothManager: BluetoothManager
    private var dataBuffer = Data() // Buffer for incoming data
    private var pollTimer: Timer? // Timer for polling OBD data
    private var activeCommands: [String] = [] // Currently active PID requests
    private var commandQueue: [String] = [] // Queue of commands to be sent
    private var isProcessingCommand = false // Flag to track if a command is in progress
    
    // The list of standard PID codes we want to query
    private let standardPIDs: [String: String] = [
        "0100": "Supported PIDs (00-1F)",
        "0120": "Supported PIDs (20-3F)",
        "0140": "Supported PIDs (40-5F)",
        "0160": "Supported PIDs (60-7F)",
        "0180": "Supported PIDs (80-9F)",
        "01A0": "Supported PIDs (A0-BF)",
        "01C0": "Supported PIDs (C0-DF)",
        
        "010C": "Engine RPM",
        "010D": "Vehicle Speed",
        "010F": "Intake Air Temperature",
        "0111": "Throttle Position",
        "0105": "Engine Coolant Temperature",
        "015C": "Oil Temperature",
        "012F": "Fuel Level",
        "010B": "Intake Manifold Pressure",
        "0110": "MAF Air Flow Rate",
        "010A": "Fuel Pressure"
    ]

    private init() {
        self.bluetoothManager = BluetoothManager.shared
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe Bluetooth connection status changes
        bluetoothManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                
                self.isDeviceConnected = connected
                
                if connected {
                    // Delay to ensure the OBD device is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.initializeOBDConnection()
                    }
                } else {
                    // Stop data polling when disconnected
                    self.stopPolling()
                    self.resetValues()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Switch between metric and imperial units
    func switchUnits(toMetric: Bool) {
        useMetricUnits = toMetric
        print("Units switched to \(useMetricUnits ? "Metric" : "Imperial")")
    }

    /// Start reading OBD2 data
    func startReadingData() {
        guard !isDeviceConnected else {
            print("OBD2 reading already started.")
            return
        }
        
        print("OBD2 connection starting...")
        bluetoothManager.startScan()
    }

    /// Stop reading OBD2 data
    func stopReadingData() {
        print("OBD2 reading stopped.")
        stopPolling()
        bluetoothManager.stopScan()
        
        if isDeviceConnected {
            // Send ATZ to reset the OBD adapter
            sendCommand("ATZ\r")
            
            // Small delay before disconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.bluetoothManager.disconnect()
            }
        }
    }

    /// Request specific OBD2 PID data
    func requestPID(_ pid: String) {
        guard isDeviceConnected else {
            print("OBD2 not connected, cannot request PID: \(pid)")
            return
        }
        
        // Add to queue if not already in active commands
        if !activeCommands.contains(pid) && !commandQueue.contains(pid) {
            commandQueue.append(pid)
            processCommandQueue()
        }
    }
    
    /// Parse incoming OBD2 response data
    func parseOBDResponse(_ data: Data) {
        // Add data to buffer
        dataBuffer.append(data)
        
        // Try to extract complete messages from buffer
        while let response = extractNextResponse(from: dataBuffer) {
            processResponse(response)
        }
    }
    
    /// Clear any stored DTCs (Diagnostic Trouble Codes)
    func clearDTCs() {
        guard isDeviceConnected else { return }
        
        // Send the clear DTCs command
        sendCommand("04\r")
    }
    
    // MARK: - Private Methods
    
    private func initializeOBDConnection() {
        print("Initializing OBD connection...")
        
        // Reset data buffer
        dataBuffer = Data()
        
        // Reset commands tracking
        activeCommands = []
        commandQueue = []
        
        // Initial commands for ELM327 setup
        let initCommands = [
            "ATZ\r",          // Reset adapter
            "ATE0\r",         // Echo off
            "ATL0\r",         // Linefeeds off
            "ATS0\r",         // Spaces off
            "ATH0\r",         // Headers off
            "ATAT1\r",        // Adaptive timing on
            "ATSP0\r"         // Auto-select protocol
        ]
        
        // Enqueue initialization commands
        commandQueue.append(contentsOf: initCommands)
        
        // Begin processing commands
        processCommandQueue()
        
        // After a delay, check supported PIDs
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.discoverSupportedPIDs()
        }
    }
    
    private func discoverSupportedPIDs() {
        // Request for supported PIDs
        commandQueue.append("0100\r") // PIDs 01-20
        processCommandQueue()
    }
    
    private func startPolling() {
        guard pollTimer == nil else { return }
        
        print("Starting OBD2 data polling...")
        
        // Create timer to regularly request PIDs
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: pollFrequency,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // Request essential PIDs
            if self.availablePIDs["010C"] == true { self.requestPID("010C\r") }  // RPM
            if self.availablePIDs["010D"] == true { self.requestPID("010D\r") }  // Speed
            if self.availablePIDs["0111"] == true { self.requestPID("0111\r") }  // Throttle
            if self.availablePIDs["0105"] == true { self.requestPID("0105\r") }  // Coolant Temp
            if self.availablePIDs["015C"] == true { self.requestPID("015C\r") }  // Oil Temp
            
            // Less frequent PIDs - request every 5 seconds
            if Int(Date().timeIntervalSince1970) % 5 == 0 {
                if self.availablePIDs["010F"] == true { self.requestPID("010F\r") }  // Intake Temp
                if self.availablePIDs["012F"] == true { self.requestPID("012F\r") }  // Fuel Level
                if self.availablePIDs["010B"] == true { self.requestPID("010B\r") }  // Manifold Pressure
            }
        }
        
        // Fire immediately
        pollTimer?.fire()
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func resetValues() {
        currentSpeed = 0
        currentRPM = 0
        throttle = 0
        oilTemperature = 0
        engineTemperature = 0
        intakeTemperature = 0
        fuelLevel = 0
        boostPressure = 0
    }
    
    private func processCommandQueue() {
        guard !isProcessingCommand && !commandQueue.isEmpty else { return }
        
        isProcessingCommand = true
        
        let command = commandQueue.removeFirst()
        activeCommands.append(command)
        
        sendCommand(command)
        
        // Set timeout for command
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            // Remove from active commands if it's still there
            if let index = self.activeCommands.firstIndex(of: command) {
                self.activeCommands.remove(at: index)
            }
            
            self.isProcessingCommand = false
            self.processCommandQueue() // Process next command
        }
    }
    
    private func sendCommand(_ command: String) {
        print("Sending OBD command: \(command)")
        bluetoothManager.sendCommand(command)
    }
    
    private func extractNextResponse(from buffer: Data) -> Data? {
        // Look for carriage return or prompt character
        if let range = buffer.range(of: Data([0x0D])) ?? buffer.range(of: Data([0x3E])) {
            let response = buffer[..<range.lowerBound]
            
            // Remove the processed data including the delimiter
            dataBuffer.removeSubrange(0...range.lowerBound)
            
            return response
        }
        return nil
    }
    
    private func processResponse(_ response: Data) {
        guard let responseString = String(data: response, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("Cannot decode response data")
            return
        }
        
        print("OBD response: \(responseString)")
        
        // Handle ELM327 responses
        if responseString.starts(with: "ATZ") || responseString.starts(with: "ELM327") {
            // Adapter reset or identification
            print("OBD adapter identified: \(responseString)")
            return
        }
        
        if responseString == "OK" || responseString == "?" || responseString.contains("ERROR") {
            // Command acknowledgement or error
            return
        }
        
        // Process OBD responses
        if responseString.starts(with: "41") {
            // This is a Mode 01 response
            let components = responseString.split(separator: " ")
            
            if components.count >= 2 {
                let responseMode = String(components[0])
                let responsePID = String(components[1])
                
                switch responseMode + responsePID {
                case "410C": // Engine RPM
                    if components.count >= 4,
                       let A = Int(components[2], radix: 16),
                       let B = Int(components[3], radix: 16) {
                        currentRPM = Double((A * 256 + B) / 4)
                    }
                
                case "410D": // Vehicle Speed
                    if components.count >= 3,
                       let A = Int(components[2], radix: 16) {
                        let speedKPH = Double(A)
                        currentSpeed = useMetricUnits ? speedKPH : speedKPH * 0.621371
                    }
                
                case "4111": // Throttle Position
                    if components.count >= 3,
                       let A = Int(components[2], radix: 16) {
                        throttle = Double(A) * 100 / 255
                    }
                
                case "415C": // Oil Temperature
                    if components.count >= 3,
                       let A = Int(components[2], radix: 16) {
                        let tempC = Double(A) - 40
                        oilTemperature = useMetricUnits ? tempC : tempC * 9/5 + 32
                    }
                
                case "4105": // Engine Coolant Temperature
                    if components.count >= 3,
                       let A = Int(components[2], radix: 16) {
                        let tempC = Double(A) - 40
                        engineTemperature = useMetricUnits ? tempC : tempC * 9/5 + 32
                    }
                
                case "410F": // Intake Air Temperature
                    if components.count >= 3,
                       let A = Int(components[2], radix: 16) {
                        let tempC = Double(A) - 40
                        intakeTemperature = useMetricUnits ? tempC : tempC * 9/5 + 32
                    }
                
                case "412F": // Fuel Level
                    if components.count >= 3,
                       let A = Int(components[2], radix: 16) {
                        fuelLevel = Double(A) * 100 / 255
                    }
                
                case "410B": // Intake Manifold Pressure (MAP)
                    if components.count >= 3,
                       let A = Int(components[2], radix: 16) {
                        // Convert kPa to PSI for display if using imperial
                        let kPa = Double(A)
                        boostPressure = useMetricUnits ? kPa : kPa * 0.145038
                    }
                
                case "4100": // Supported PIDs 01-20
                    if components.count >= 6 {
                        parseSupportedPIDs(components: components, range: 0x00...0x1F)
                    }
                
                case "4120": // Supported PIDs 21-40
                    if components.count >= 6 {
                        parseSupportedPIDs(components: components, range: 0x20...0x3F)
                    }
                
                case "4140": // Supported PIDs 41-60
                    if components.count >= 6 {
                        parseSupportedPIDs(components: components, range: 0x40...0x5F)
                    }
                
                case "4160": // Supported PIDs 61-80
                    if components.count >= 6 {
                        parseSupportedPIDs(components: components, range: 0x60...0x7F)
                    }
                
                default:
                    break
                }
            }
        } else if responseString.starts(with: "43") {
            // Mode 03 response - DTCs
            parseDTCs(responseString)
        }
        
        // Remove from active commands
        for (index, cmd) in activeCommands.enumerated() {
            if cmd.contains(responseString.prefix(2)) {
                activeCommands.remove(at: index)
                break
            }
        }
        
        // After processing response, continue with next command
        isProcessingCommand = false
        processCommandQueue()
        
        // If this was from initialization sequence and we're done, start polling
        if activeCommands.isEmpty && commandQueue.isEmpty && availablePIDs.count > 0 {
            startPolling()
        }
    }
    
    private func parseSupportedPIDs(components: [Substring], range: ClosedRange<Int>) {
        guard components.count >= 6 else { return }
        
        // Extract 4 bytes of PID support data
        if let A = Int(components[2], radix: 16),
           let B = Int(components[3], radix: 16),
           let C = Int(components[4], radix: 16),
           let D = Int(components[5], radix: 16) {
            
            let supportData: UInt32 = UInt32(A) << 24 | UInt32(B) << 16 | UInt32(C) << 8 | UInt32(D)
            
            // Process each bit
            for i in 0..<32 {
                let pid = range.lowerBound + i
                let pidSupported = (supportData >> (31 - i)) & 1 == 1
                
                // Format PID as OBD command
                let pidHex = String(format: "01%02X", pid)
                
                // Update available PIDs dictionary
                availablePIDs[pidHex] = pidSupported
                
                if pidSupported {
                    print("Supported PID: \(pidHex)")
                }
            }
            
            // Check if the next range is supported
            let nextRangeSupported = (supportData & 1) == 1
            
            // Request next range if supported
            if nextRangeSupported {
                let nextPIDRange = range.upperBound + 1
                if nextPIDRange <= 0xE0 {
                    let nextPID = String(format: "01%02X\r", nextPIDRange)
                    commandQueue.append(nextPID)
                }
            }
        }
    }
    
    private func parseDTCs(_ response: String) {
        // Example response: "43 01 33 00 00 00 00"
        // Format is code type and 2 bytes for each DTC
        let components = response.split(separator: " ")
        
        if components.count >= 2 {
            var codes: [String] = []
            
            for i in stride(from: 1, to: components.count, by: 2) {
                if i + 1 < components.count, components[i] != "00" || components[i+1] != "00" {
                    if let firstByte = Int(components[i], radix: 16),
                       let secondByte = Int(components[i+1], radix: 16) {
                        
                        // Extract DTC information
                        let firstDigit = (firstByte >> 6) & 0x03 // First 2 bits (type)
                        let secondDigit = firstByte & 0x3F // Last 6 bits
                        
                        var codePrefix = ""
                        switch firstDigit {
                        case 0: codePrefix = "P" // Powertrain
                        case 1: codePrefix = "C" // Chassis
                        case 2: codePrefix = "B" // Body
                        case 3: codePrefix = "U" // Network
                        default: codePrefix = "X" // Unknown
                        }
                        
                        let dtcCode = String(format: "%@%01X%02X", codePrefix, secondDigit, secondByte)
                        codes.append(dtcCode)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.dtcCodes = codes
            }
        }
    }
}

extension OBD2Manager: CustomStringConvertible {
    var description: String {
        return """
        OBD2Manager Status:
        - Connected: \(isDeviceConnected)
        - Units: \(useMetricUnits ? "Metric" : "Imperial")
        - Speed: \(currentSpeed) \(useMetricUnits ? "km/h" : "mph")
        - RPM: \(currentRPM)
        - Throttle: \(throttle)%
        - Oil Temp: \(oilTemperature) \(useMetricUnits ? "°C" : "°F")
        """
    }
}
