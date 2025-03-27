//
//  OBDModels.swift
//  RaceBoxLapTimer
//

import Foundation

// MARK: - OBD PID Data Structure

struct OBDParameter: Identifiable, Codable {
    var id: String          // PID code (e.g., "0C" for RPM)
    var name: String        // Human-readable name
    var unit: String        // Measurement unit
    var min: Double         // Minimum expected value
    var max: Double         // Maximum expected value
    var value: Double?      // Current value
    var mode: UInt8         // OBD mode (usually 01 for current data)
    var formula: OBDFormula // Formula to convert raw data
    var bytes: Int          // Number of data bytes expected
    var priority: Int       // Priority for polling (lower = higher priority)
    
    // Convert a response into a value based on formula
    func calculateValue(from response: [UInt8]) -> Double? {
        guard response.count >= bytes else { return nil }
        
        switch formula {
        case .direct:
            return Double(response[0])
            
        case .percentage:
            return Double(response[0]) * 100.0 / 255.0
            
        case .temperature:
            return Double(response[0]) - 40.0
            
        case .rpm:
            let a = UInt16(response[0])
            let b = UInt16(response[1])
            return Double((a * 256) + b) / 4.0
            
        case .speed:
            return Double(response[0])
            
        case .throttlePosition:
            return Double(response[0]) * 100.0 / 255.0
            
        case .engineLoad:
            return Double(response[0]) * 100.0 / 255.0
            
        case .customA:
            // Custom formula for specific parameters
            // Example: Fuel pressure = (response[0] * 3)
            return Double(response[0]) * 3.0
            
        case .customB:
            // Another custom formula
            // Example: Timing advance = (response[0] / 2) - 64
            return (Double(response[0]) / 2.0) - 64.0
            
        case .pressure:
            return Double(response[0]) * 3.0
            
        case .voltage:
            return Double(response[0]) / 10.0
            
        case .multiByteValue:
            var value: UInt32 = 0
            for i in 0..<min(4, response.count) {
                value = (value << 8) | UInt32(response[i])
            }
            return Double(value)
        }
    }
}

// MARK: - OBD Calculation Formula Types

enum OBDFormula: String, Codable {
    case direct           // Direct value (A)
    case percentage       // Percentage (A * 100 / 255)
    case temperature      // Temperature (A - 40)
    case rpm              // RPM ((A * 256) + B) / 4
    case speed            // Speed (A)
    case throttlePosition // Throttle Position (A * 100 / 255)
    case engineLoad       // Engine Load (A * 100 / 255)
    case customA          // Custom formula A (e.g., Fuel pressure)
    case customB          // Custom formula B (e.g., Timing advance)
    case pressure         // Pressure (A * 3)
    case voltage          // Voltage (A / 10)
    case multiByteValue   // Multi-byte value
}

// MARK: - Standard OBD-II PIDs

struct OBDPIDs {
    // Mode 01 PIDs - Current Data
    static let engineLoad = OBDParameter(
        id: "04",
        name: "Engine Load",
        unit: "%",
        min: 0,
        max: 100,
        mode: 0x01,
        formula: .engineLoad,
        bytes: 1,
        priority: 3
    )
    
    static let coolantTemp = OBDParameter(
        id: "05",
        name: "Coolant Temp",
        unit: "°C",
        min: -40,
        max: 215,
        mode: 0x01,
        formula: .temperature,
        bytes: 1,
        priority: 2
    )
    
    static let rpm = OBDParameter(
        id: "0C",
        name: "Engine RPM",
        unit: "rpm",
        min: 0,
        max: 10000,
        mode: 0x01,
        formula: .rpm,
        bytes: 2,
        priority: 1
    )
    
    static let speed = OBDParameter(
        id: "0D",
        name: "Vehicle Speed",
        unit: "km/h",
        min: 0,
        max: 255,
        mode: 0x01,
        formula: .speed,
        bytes: 1,
        priority: 1
    )
    
    static let throttlePosition = OBDParameter(
        id: "11",
        name: "Throttle Position",
        unit: "%",
        min: 0,
        max: 100,
        mode: 0x01,
        formula: .throttlePosition,
        bytes: 1,
        priority: 1
    )
    
    static let intakeAirTemp = OBDParameter(
        id: "0F",
        name: "Intake Air Temp",
        unit: "°C",
        min: -40,
        max: 215,
        mode: 0x01,
        formula: .temperature,
        bytes: 1,
        priority: 3
    )
    
    static let mafRate = OBDParameter(
        id: "10",
        name: "MAF Rate",
        unit: "g/s",
        min: 0,
        max: 655.35,
        mode: 0x01,
        formula: .multiByteValue,
        bytes: 2,
        priority: 2
    )
    
    static let oilTemp = OBDParameter(
        id: "5C",
        name: "Oil Temperature",
        unit: "°C",
        min: -40,
        max: 215,
        mode: 0x01,
        formula: .temperature,
        bytes: 1,
        priority: 2
    )
    
    static let boost = OBDParameter(
        id: "0B",
        name: "Intake Manifold Pressure",
        unit: "kPa",
        min: 0,
        max: 255,
        mode: 0x01,
        formula: .pressure,
        bytes: 1,
        priority: 1
    )
    
    // Mode 09 PIDs - Vehicle Information
    static let vin = OBDParameter(
        id: "02",
        name: "Vehicle Identification Number",
        unit: "",
        min: 0,
        max: 0,
        mode: 0x09,
        formula: .direct,
        bytes: 20,
        priority: 10
    )
    
    // Default set of parameters to monitor
    static let defaultParameters: [OBDParameter] = [
        rpm,
        speed,
        throttlePosition,
        engineLoad,
        coolantTemp,
        boost,
        oilTemp
    ]
}

// MARK: - OBD Response

struct OBDResponse {
    var parameter: OBDParameter
    var rawData: [UInt8]
    var value: Double?
    var timestamp: Date
    
    init(parameter: OBDParameter, rawData: [UInt8], timestamp: Date = Date()) {
        self.parameter = parameter
        self.rawData = rawData
        self.timestamp = timestamp
        self.value = parameter.calculateValue(from: rawData)
    }
    
    var formattedValue: String {
        guard let value = value else { return "N/A" }
        
        switch parameter.id {
        case OBDPIDs.rpm.id:
            return String(format: "%.0f \(parameter.unit)", value)
        case OBDPIDs.throttlePosition.id, OBDPIDs.engineLoad.id:
            return String(format: "%.1f \(parameter.unit)", value)
        case OBDPIDs.speed.id:
            return String(format: "%.0f \(parameter.unit)", value)
        case OBDPIDs.coolantTemp.id, OBDPIDs.oilTemp.id, OBDPIDs.intakeAirTemp.id:
            return String(format: "%.0f \(parameter.unit)", value)
        case OBDPIDs.boost.id:
            return String(format: "%.0f \(parameter.unit)", value)
        default:
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f \(parameter.unit)", value)
            } else {
                return String(format: "%.1f \(parameter.unit)", value)
            }
        }
    }
}

// MARK: - Vehicle Data Structure

struct VehicleData {
    var rpm: Double?
    var speed: Double?
    var throttlePosition: Double?
    var brakePosition: Double?  // Not directly available from OBD but can be derived
    var engineLoad: Double?
    var coolantTemp: Double?
    var intakeAirTemp: Double?
    var oilTemp: Double?
    var boostPressure: Double?
    var gear: Int?
    
    // Derive gear based on RPM and speed
    mutating func deriveGear() {
        guard let rpm = rpm, let speed = speed, rpm > 0, speed > 0 else {
            gear = nil
            return
        }
        
        // This is a very simplified gear estimation that should be calibrated
        // for each specific vehicle's gear ratios
        let ratio = (rpm / speed)
        
        if ratio > 110 {
            gear = 1
        } else if ratio > 70 {
            gear = 2
        } else if ratio > 50 {
            gear = 3
        } else if ratio > 40 {
            gear = 4
        } else if ratio > 30 {
            gear = 5
        } else {
            gear = 6
        }
    }
    
    // Clean up by removing extreme outliers
    mutating func sanitize() {
        if let rpm = rpm, rpm > 10000 || rpm < 0 {
            self.rpm = nil
        }
        
        if let speed = speed, speed > 350 || speed < 0 {
            self.speed = nil
        }
        
        if let throttle = throttlePosition, throttle > 100 || throttle < 0 {
            self.throttlePosition = nil
        }
        
        if let brake = brakePosition, brake > 100 || brake < 0 {
            self.brakePosition = nil
        }
        
        if let temp = coolantTemp, temp > 150 || temp < -40 {
            self.coolantTemp = nil
        }
        
        if let temp = oilTemp, temp > 150 || temp < -40 {
            self.oilTemp = nil
        }
        
        if let pressure = boostPressure, pressure > 400 || pressure < 0 {
            self.boostPressure = nil
        }
    }
}
