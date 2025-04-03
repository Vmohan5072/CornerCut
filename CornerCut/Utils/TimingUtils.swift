import Foundation

struct TimingUtils {
    // MARK: - Lap Time Formatting
    
    /// Format a lap time as MM:SS.mmm
    static func formatLapTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
    
    /// Format a sector time as SS.mmm
    static func formatSectorTime(_ time: TimeInterval?) -> String {
        guard let time = time else { return "--:--.---" }
        
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d.%03d", seconds, milliseconds)
    }
    
    /// Format a delta time with sign as +/- SS.mmm
    static func formatDeltaTime(_ delta: TimeInterval) -> String {
        let sign = delta >= 0 ? "+" : "-"
        let absDelta = abs(delta)
        
        let seconds = Int(absDelta) % 60
        let milliseconds = Int((absDelta.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%@%02d.%03d", sign, seconds, milliseconds)
    }
    
    /// Format a session duration as HH:MM:SS or MM:SS
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Timing Operations
    
    /// Measure execution time of a block of code
    static func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let end = CFAbsoluteTimeGetCurrent()
        
        let duration = end - start
        logInfo("\(name) took \(String(format: "%.3f", duration * 1000))ms", category: .performance)
        
        return result
    }
    
    /// Measure execution time of an async block of code
    static func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let end = CFAbsoluteTimeGetCurrent()
        
        let duration = end - start
        logInfo("\(name) took \(String(format: "%.3f", duration * 1000))ms", category: .performance)
        
        return result
    }
    
    // MARK: - Performance Tracking
    
    /// A simple timer class for tracking operations
    class PerformanceTimer {
        private let name: String
        private let category: LogCategory
        private let startTime: CFAbsoluteTime
        private var lapTimes: [(name: String, time: CFAbsoluteTime)] = []
        
        init(_ name: String, category: LogCategory = .performance) {
            self.name = name
            self.category = category
            self.startTime = CFAbsoluteTimeGetCurrent()
            
            logDebug("Started timer: \(name)", category: category)
        }
        
        func lap(_ name: String) {
            let now = CFAbsoluteTimeGetCurrent()
            let previousTime = lapTimes.last?.time ?? startTime
            let lapDuration = now - previousTime
            
            lapTimes.append((name, now))
            
            logDebug("Lap '\(name)' took \(String(format: "%.3f", lapDuration * 1000))ms", category: category)
        }
        
        func stop() -> TimeInterval {
            let endTime = CFAbsoluteTimeGetCurrent()
            let totalDuration = endTime - startTime
            
            // Log each lap
            var previousTime = startTime
            for (index, lap) in lapTimes.enumerated() {
                let lapDuration = lap.time - previousTime
                logDebug("Lap \(index + 1): '\(lap.name)' took \(String(format: "%.3f", lapDuration * 1000))ms", category: category)
                previousTime = lap.time
            }
            
            // Log total
            logInfo("Timer '\(name)' completed in \(String(format: "%.3f", totalDuration * 1000))ms", category: category)
            
            return totalDuration
        }
    }
    
    // MARK: - Throttling & Debouncing
    
    /// A simple utility to throttle function calls
    class Throttler {
        private let queue: DispatchQueue
        private var lastFireTime: DispatchTime = .now()
        private let delay: TimeInterval
        
        init(delay: TimeInterval, queue: DispatchQueue = .main) {
            self.delay = delay
            self.queue = queue
        }
        
        func throttle(action: @escaping () -> Void) {
            let now = DispatchTime.now()
            let timeSinceLastFire = now.distance(to: lastFireTime).seconds
            
            if timeSinceLastFire < 0 || timeSinceLastFire > delay {
                lastFireTime = now + delay
                queue.async {
                    action()
                }
            }
        }
    }
    
    /// A simple utility to debounce function calls
    class Debouncer {
        private let queue: DispatchQueue
        private var workItem: DispatchWorkItem?
        private let delay: TimeInterval
        
        init(delay: TimeInterval, queue: DispatchQueue = .main) {
            self.delay = delay
            self.queue = queue
        }
        
        func debounce(action: @escaping () -> Void) {
            workItem?.cancel()
            
            let newWorkItem = DispatchWorkItem { action() }
            workItem = newWorkItem
            
            queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
        }
        
        func cancel() {
            workItem?.cancel()
            workItem = nil
        }
    }
}
