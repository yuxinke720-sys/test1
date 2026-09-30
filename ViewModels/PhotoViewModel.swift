// CHANGED: Replaced fake Task.sleep stub in analyzePhotos() with real AIService.analyzeChildAppearance call.
// CHANGED: Added @Published childAppearanceDescription property to carry extracted features downstream.
// CHANGED: Graceful degradation — on failure, sets analysisComplete = true with empty description.
import SwiftUI
import PhotosUI

@MainActor
class PhotoViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var photosPickerItems: [PhotosPickerItem] = []
    @Published var isAnalyzing = false
    @Published var analysisComplete = false
    @Published var errorMessage: String?
    @Published var childAppearanceDescription: String = ""

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
        childAppearanceDescription = ""

        do {
            let description = try await AIService.shared.analyzeChildAppearance(from: selectedImages)
            childAppearanceDescription = description
            print("[PhotoVM] Appearance extracted: \(description)")
        } catch {
            print("[PhotoVM] Appearance analysis failed: \(error.localizedDescription)")
            errorMessage = "Couldn't analyze photos. A default style will be used."
            childAppearanceDescription = ""
        }

        isAnalyzing = false
        analysisComplete = true
    }

    func reset() {
        selectedImages = []
        photosPickerItems = []
        isAnalyzing = false
        analysisComplete = false
        errorMessage = nil
        childAppearanceDescription = ""
    }
}
