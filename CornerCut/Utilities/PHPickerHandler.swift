import PhotosUI

class PHPickerHandler: NSObject, PHPickerViewControllerDelegate {
    private let completion: ([PHPickerResult]) -> Void

    init(completion: @escaping ([PHPickerResult]) -> Void) {
        self.completion = completion
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        completion(results)
    }
}
