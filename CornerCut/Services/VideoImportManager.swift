import Foundation
import PhotosUI
import SwiftUI

final class VideoImportManager: ObservableObject {
    static let shared = VideoImportManager() // Singleton instance

    @Published var selectedVideoURL: URL? // Stores the selected video URL

    private init() {}

    /// Opens the video picker and allows the user to select a video from their camera roll.
    func importVideo(completion: @escaping (URL?) -> Void) {
        var pickerConfig = PHPickerConfiguration(photoLibrary: .shared())
        pickerConfig.filter = .videos // Only allow videos
        pickerConfig.selectionLimit = 1 // Allow a single video to be selected

        let picker = PHPickerViewController(configuration: pickerConfig)
        picker.delegate = self

        // Use a presentation mechanism to display the picker.
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(picker, animated: true, completion: nil)
        }

        // Completion handler for video import.
        self.completionHandler = completion
    }

    private var completionHandler: ((URL?) -> Void)?
}

extension VideoImportManager: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            // No video was selected
            completionHandler?(nil)
            return
        }

        if result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    if let error = error {
                        print("Error loading video: \(error.localizedDescription)")
                        self.completionHandler?(nil)
                    } else if let url = url {
                        // Copy the file to a temporary location for persistent use
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            self.selectedVideoURL = tempURL
                            self.completionHandler?(tempURL)
                        } catch {
                            print("Error copying video to temporary directory: \(error.localizedDescription)")
                            self.completionHandler?(nil)
                        }
                    }
                }
            }
        } else {
            print("Selected item is not a video.")
            completionHandler?(nil)
        }
    }
}
