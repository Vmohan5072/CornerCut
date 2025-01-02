import Foundation
import Combine
import SwiftUI

final class OBD2Manager: ObservableObject {
    static let shared = OBD2Manager() // Singleton instance

    @Published var currentSpeed: Double = 0 // Speed (in user-selected unit)
    @Published var currentRPM: Double = 0 // Engine RPM
    @Published var throttle: Double = 0 // Throttle Position (%)
    @Published var oilTemperature: Double = 0 // Oil Temperature (°C or °F based on units)

    @AppStorage("useMetricUnits") private var useMetricUnits: Bool = false // User's unit preference

    private var bluetoothManager: BluetoothManager
    private var dataBuffer = Data() // Buffer for incoming data

    private init() {
        self.bluetoothManager = BluetoothManager.shared
    }

    /// Switch between metric and imperial units
    func switchUnits(toMetric: Bool) {
        useMetricUnits = toMetric
        print("Units switched to \(useMetricUnits ? "Metric" : "Imperial")")
    }

    /// Start reading OBD2 data
    func startReadingData() {
        print("OBD2 reading started.")
        sendPIDRequest(pid: "010C") // Engine RPM
        sendPIDRequest(pid: "010D") // Vehicle Speed
        sendPIDRequest(pid: "0111") // Throttle Position
        sendPIDRequest(pid: "015C") // Oil Temperature
    }

    /// Stop reading OBD2 data
    func stopReadingData() {
        print("OBD2 reading stopped.")
    }

    /// Send a PID request to the OBD2 device
    private func sendPIDRequest(pid: String) {
        let command = "\(pid)\r"
        bluetoothManager.sendCommand(command)
    }

    /// Parse incoming OBD2 response data
    func parseOBDResponse(_ data: Data) {
        dataBuffer.append(data)
        while let response = extractNextResponse(from: dataBuffer) {
            processResponse(response)
        }
    }

    /// Extract the next response from the buffer
    private func extractNextResponse(from buffer: Data) -> Data? {
        if let range = buffer.range(of: Data([0x0D])) { // Look for '\r' delimiter
            let response = buffer[..<range.lowerBound]
            dataBuffer.removeSubrange(...range.upperBound)
            return response
        }
        return nil
    }

    /// Process a single OBD2 response
    private func processResponse(_ response: Data) {
        guard let responseString = String(data: response, encoding: .utf8) else { return }
        let components = responseString.split(separator: " ")

        guard components.count >= 3 else { return }

        if components[0] == "41" { // Response for mode 01
            switch components[1] {
            case "0C": // Engine RPM
                if components.count >= 4, let A = Int(components[2], radix: 16), let B = Int(components[3], radix: 16) {
                    currentRPM = Double((A * 256 + B) / 4)
                }
            case "0D": // Vehicle Speed
                if components.count >= 3, let A = Int(components[2], radix: 16) {
                    let speedKMPH = Double(A) // Speed in km/h
                    currentSpeed = calculateSpeed(rawSpeed: speedKMPH)
                }
            case "11": // Throttle Position
                if components.count >= 3, let A = Int(components[2], radix: 16) {
                    throttle = Double(A) * 100 / 255 // Percentage
                }
            case "5C": // Oil Temperature
                if components.count >= 3, let A = Int(components[2], radix: 16) {
                    oilTemperature = calculateTemperature(rawTemp: Double(A))
                }
            default:
                break
            }
        }
    }

    /// Calculate the speed based on the selected units
    private func calculateSpeed(rawSpeed: Double) -> Double {
        return useMetricUnits ? rawSpeed : rawSpeed * 0.621371 // Convert to mph if imperial
    }

    /// Calculate the temperature based on the selected units
    private func calculateTemperature(rawTemp: Double) -> Double {
        let celsius = rawTemp - 40
        return useMetricUnits ? celsius : celsius * 9/5 + 32 // Convert to °F if imperial
    }
}
