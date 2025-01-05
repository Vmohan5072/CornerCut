import SwiftUI
import UIKit

struct VideoImportView: View {
    @State private var selectedVideoURL: URL?

    var body: some View {
        VStack {
            if let url = selectedVideoURL {
                Text("Selected Video: \(url.lastPathComponent)")
                    .font(.subheadline)
                    .padding()
            } else {
                Text("No video selected")
                    .font(.subheadline)
                    .padding()
            }

            Button("Import GoPro Video") {
                showDocumentPicker()
            }
            .padding()

            Spacer()
        }
        .navigationTitle("Import Video")
    }

    private func showDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie])
        picker.delegate = DocumentPickerCoordinator { url in
            DispatchQueue.main.async {
                self.selectedVideoURL = url
            }
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .keyWindow?
            .rootViewController?
            .present(picker, animated: true)
    }
}

class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}
