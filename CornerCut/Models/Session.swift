import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var date: Date
    var trackName: String
    var laps: [Lap] = []
    var customName: String?
    var usingExternalGPS: Bool
    var videoURL: URL? // Video file linked to this session

    init(
        trackName: String,
        usingExternalGPS: Bool,
        customName: String? = nil,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.trackName = trackName
        self.usingExternalGPS = usingExternalGPS
        self.customName = customName
        self.date = date
    }
}
