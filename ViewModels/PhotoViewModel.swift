import SwiftUI
import PhotosUI

@MainActor
class PhotoViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var photosPickerItems: [PhotosPickerItem] = []
    @Published var isAnalyzing = false
    @Published var analysisComplete = false
    @Published var errorMessage: String?

    let maxPhotos = 10
    let minPhotos = 1

    var canContinue: Bool {
        selectedImages.count >= minPhotos
    }

    var photoCountText: String {
        "\(selectedImages.count) / \(maxPhotos) photos"
    }

    var statusText: String {
        if selectedImages.count >= minPhotos {
            return "Ready to continue ✓"
        }
        return "Add at least \(minPhotos) photo to continue"
    }

    func loadPhotos() async {
        var newImages: [UIImage] = []
        for item in photosPickerItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(image)
            }
        }

        let remaining = maxPhotos - selectedImages.count
        selectedImages.append(contentsOf: newImages.prefix(remaining))
        photosPickerItems = []
    }

    func removePhoto(at index: Int) {
        guard index < selectedImages.count else { return }
        withAnimation(.spring(response: 0.3)) {
            _ = selectedImages.remove(at: index)
        }
    }

    func analyzePhotos() async {
        isAnalyzing = true
        errorMessage = nil

        // Simulate AI face-feature extraction
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        isAnalyzing = false
        analysisComplete = true
    }

    func reset() {
        selectedImages = []
        photosPickerItems = []
        isAnalyzing = false
        analysisComplete = false
        errorMessage = nil
    }
}
