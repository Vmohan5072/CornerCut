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
    func exportVideo(exportSession: AVAssetExportSession?) async -> URL? {
        guard let exportSession = exportSession else {
            return nil
        }

        // Set the output file URL and file type
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("overlayed_video_\(Date().timeIntervalSince1970).mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        do {
            // Perform the export asynchronously using the `export` function
            try await exportSession.export()
            return exportSession.outputURL
        } catch {
            print("Export failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // This bridging method allows older code to use the async function with a completion handler
    func exportVideoWithCompletion(exportSession: AVAssetExportSession?, completion: @escaping (URL?) -> Void) {
        Task {
            let url = await exportVideo(exportSession: exportSession)
            
            // Switch back to the main thread for UI updates
            await MainActor.run {
                completion(url)
            }
        }
    }
}
