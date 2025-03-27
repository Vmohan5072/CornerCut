//
//  OBDPacketDecoder.swift
//  RaceBoxLapTimer
//

import Foundation

class OBDPacketDecoder {
    
    // MARK: - Constants
    
    static let ELM_PROMPT: String = ">"
    static let ELM_OK: String = "OK"
    static let ELM_ERROR: String = "ERROR"
    static let ELM_NO_DATA: String = "NO DATA"
    static let ELM_SEARCH: String = "SEARCHING..."
    
    // MARK: - Command Generation
    
    /// Generate an OBD-II command for a parameter
    static func generateCommand(for parameter: OBDParameter) -> String {
        return String(format: "%02X%@", parameter.mode, parameter.id)
    }
    
    /// Generate AT command for ELM327 setup
    static func generateATCommand(_ command: String) -> String {
        return "AT" + command
    }
    
    /// Add carriage return to command (required for ELM327)
    static func finalizeCommand(_ command: String) -> String {
        return command + "\r"
    }
    
    /// Prepare an ELM initialization sequence
    static func generateInitializationSequence() -> [String] {
        return [
            "ATZ",             // Reset
            "ATE0",            // Echo off
            "ATL0",            // Linefeeds off
            "ATS0",            // Spaces off
            "ATH0",            // Headers off
            "ATAT1",           // Adaptive timing on
            "ATSP0",           // Auto protocol
            "0100"             // OBD support command
        ]
    }
    
    // MARK: - Response Parsing
    
    /// Parse a response from the ELM327 adapter
    static func parseResponse(_ response: String, for parameter: OBDParameter) -> OBDResponse? {
        // Clean up response
        var cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for common issues
        if cleanResponse.contains(ELM_NO_DATA) || cleanResponse.contains(ELM_ERROR) || cleanResponse.contains(ELM_SEARCH) {
            return nil
        }
        
        // Extract data section from response
        if let responseStart = cleanResponse.range(of: parameter.id) {
            cleanResponse = String(cleanResponse[responseStart.upperBound...])
        }
        
        // Convert hex string to bytes
        var bytes: [UInt8] = []
        var startIndex = cleanResponse.startIndex
        
        while startIndex < cleanResponse.endIndex {
            let endIndex = cleanResponse.index(startIndex, offsetBy: 2, limitedBy: cleanResponse.endIndex) ?? cleanResponse.endIndex
            let byteString = cleanResponse[startIndex..<endIndex]
            
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
            
            if endIndex == cleanResponse.endIndex {
                break
            }
            
            startIndex = endIndex
        }
        
        // Create response object
        return OBDResponse(parameter: parameter, rawData: bytes)
    }
    
    /// Parse protocol identification from adapter response
    static func parseProtocolResponse(_ response: String) -> String? {
        if response.contains("AUTO") {
            let components = response.components(separatedBy: ",")
            if components.count > 1 {
                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    /// Check if ELM adapter is ready from response
    static func isAdapterReady(_ response: String) -> Bool {
        return response.contains(ELM_PROMPT) || response.contains(ELM_OK)
    }
    
    /// Check if specific command is supported based on response
    static func isCommandSupported(_ response: String, command: String) -> Bool {
        // Parse the response to check if the given command is in the support list
        // Example response: "41 00 BE 3E B8 11" for supported PIDs 01-20
        
        guard response.hasPrefix("4") else { return false }
        
        // Extract data bytes
        let components = response.components(separatedBy: " ")
        guard components.count >= 3 else { return false }
        
        // Convert command to PID number
        guard let pid = Int(command, radix: 16) else { return false }
        
        // Calculate which byte and bit to check
        let byteIndex = (pid - 1) / 8 + 2  // +2 to skip mode and PID bytes
        let bitPosition = 7 - ((pid - 1) % 8)
        
        guard byteIndex < components.count else { return false }
        guard let dataByte = UInt8(components[byteIndex], radix: 16) else { return false }
        
        // Check if the specific bit is set
        return (dataByte & (1 << bitPosition)) != 0
    }
}
