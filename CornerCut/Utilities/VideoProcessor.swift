import Foundation
import AVFoundation

final class VideoExportManager {
    static let shared = VideoExportManager() // Singleton instance

    private init() {}

    /// Exports a video with overlaid data to a temporary file.
    ///
    /// - Parameters:
    ///   - exportSession: The `AVAssetExportSession` configured for exporting the video.
    ///   - completion: A closure that returns the URL of the exported file or `nil` if the export failed.
    func exportVideo(exportSession: AVAssetExportSession?, completion: @escaping (URL?) -> Void) async {
        guard let exportSession = exportSession else {
            completion(nil)
            return
        }

        // Set the output file URL and file type
        exportSession.outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("overlayed_video.mp4")
        exportSession.outputFileType = .mp4

        do {
            // Perform the export asynchronously using the `export` function
            try await exportSession.export()
            completion(exportSession.outputURL)
        } catch {
            print("Export failed: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
