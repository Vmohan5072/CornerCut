import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var date: Date
    var trackName: String
    var laps: [Lap]
    var customName: String?
    var usingExternalGPS: Bool //is it using Racebox or not

    init(
        trackName: String,
        usingExternalGPS: Bool = false,
        customName: String? = nil //Default is blank
    ) {
        self.id = UUID()
        self.date = Date()
        self.trackName = trackName
        self.usingExternalGPS = usingExternalGPS
        self.laps = []
        self.customName = customName
    }
}
