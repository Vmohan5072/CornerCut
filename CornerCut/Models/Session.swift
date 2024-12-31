import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var date: Date
    var trackName: String
    var laps: [Lap]

    // Example: store GPS source (internal or RaceBox)
    var usingExternalGPS: Bool
    
    init(
        trackName: String,
        usingExternalGPS: Bool = false
    ) {
        self.id = UUID()
        self.date = Date()
        self.trackName = trackName
        self.usingExternalGPS = usingExternalGPS
        self.laps = []
    }
}
