import SwiftUI
import AVKit

struct SyncView: View {
    @State private var videoURL: URL
    @State private var timeOffset: TimeInterval = 0.0

    var body: some View {
        VStack {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 300)
                .padding()

            Slider(value: $timeOffset, in: -10...10, step: 0.1) {
                Text("Time Offset")
            }
            .padding()

            Text("Offset: \(timeOffset, specifier: "%.1f") seconds")
                .font(.headline)
                .padding()
        }
        .navigationTitle("Sync Timing")
    }
}
