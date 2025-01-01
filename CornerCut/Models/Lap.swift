import Foundation
import SwiftData

@Model
final class Lap {
    @Attribute(.unique) var id: UUID
    var lapNumber: Int
    var lapTime: Double // total seconds
    var telemetryData: [TelemetryData]
    
    init(lapNumber: Int, lapTime: Double) {
        self.id = UUID()
        self.lapNumber = lapNumber
        self.lapTime = lapTime
        self.telemetryData = []
    }
}
