import Foundation
import os.log

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 4
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class Logger {
    // MARK: - Properties
    
    static let shared = Logger()
    
    // Current log level - can be changed at runtime
    var logLevel: LogLevel = .debug
    
    // Whether to write logs to file
    var writeToFile: Bool = false
    
    // Enable console logs
    var consoleLogsEnabled: Bool = true
    
    // Log categories
    private let generalLog: OSLog
    private let bluetoothLog: OSLog
    private let telemetryLog: OSLog
    private let performanceLog: OSLog
    
    // Current log file path
    private var logFileURL: URL? {
        guard writeToFile else { return nil }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logDirectory = documentsDirectory.appendingPathComponent("Logs")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Create file with date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        return logDirectory.appendingPathComponent("log-\(dateString).txt")
    }
    
    // MARK: - Initialization
    
    private init() {
        generalLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "CornerCut", category: "General")
        bluetoothLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "CornerCut", category: "Bluetooth")
        telemetryLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "CornerCut", category: "Telemetry")
        performanceLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "CornerCut", category: "Performance")
    }
    
    // MARK: - Public Methods
    
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        guard level >= logLevel else { return }
        
        // Format the log entry
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        
        let formattedMessage = "[\(levelString(level))] [\(category.rawValue)] \(fileName):\(line) \(function) - \(message)"
        
        // Log to console
        if consoleLogsEnabled {
            let osLogType: OSLogType
            switch level {
            case .debug:
                osLogType = .debug
            case .info:
                osLogType = .info
            case .warning:
                osLogType = .default
            case .error:
                osLogType = .error
            case .none:
                osLogType = .default
            }
            
            let osLog = getOSLog(for: category)
            os_log("%{public}@", log: osLog, type: osLogType, formattedMessage)
        }
        
        // Log to file if enabled
        appendToLogFile(formattedMessage)
    }
    
    private func levelString(_ level: LogLevel) -> String {
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        case .none:
            return "NONE"
        }
    }
    
    private func getOSLog(for category: LogCategory) -> OSLog {
        switch category {
        case .general:
            return generalLog
        case .bluetooth:
            return bluetoothLog
        case .telemetry:
            return telemetryLog
        case .performance:
            return performanceLog
        }
    }
    
    private func appendToLogFile(_ message: String) {
        guard writeToFile, let fileURL = logFileURL else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "\(timestamp) \(message)\n"
        
        // Append to file
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try logEntry.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // If we can't write to the log file, just log to console
            os_log("Failed to write to log file: %{public}@", log: generalLog, type: .error, error.localizedDescription)
        }
    }
}

enum LogCategory: String {
    case general = "General"
    case bluetooth = "Bluetooth"
    case telemetry = "Telemetry"
    case performance = "Performance"
}

// MARK: - Global Functions for Easier Access

func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}
