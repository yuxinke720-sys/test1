import SwiftUI
import PhotosUI

struct TemplatePhotoUploadView: View {
    @ObservedObject var storyVM: StoryViewModel
    @ObservedObject var photoVM: PhotoViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                templateBanner
                photoSection
                Spacer()
                bottomButton
            }
        }
        .onChange(of: photoVM.photosPickerItems) {
            Task { await photoVM.loadPhotos() }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button { currentScreen = .templatePreview } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "E8705A"))
                    .frame(width: 36)
            }
            Spacer()
            Text("Add Photo")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1E1C1A"))
            Spacer()
            Color.clear.frame(width: 36)
        }
        .frame(height: 48)
        .padding(.horizontal, 18)
    }

    // MARK: - Template Banner

    private var templateBanner: some View {
        HStack(spacing: 12) {
            if let template = storyVM.selectedTemplate {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: template.coverGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 56)
                    .overlay(
                        Image(systemName: template.coverIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1E1C1A"))
                        .lineLimit(1)
                    Text("\(template.pages.count) pages")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "7A756E"))
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a photo of \(storyVM.childName)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1E1C1A"))
                .padding(.horizontal, 18)

            Text("One clear face photo is all we need")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(Color(hex: "7A756E"))
                .padding(.horizontal, 18)

            if let firstImage = photoVM.selectedImages.first {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: firstImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(16)

                    Button { photoVM.removePhoto(at: 0) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color(hex: "FF5252"))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
                .padding(.horizontal, 18)
            } else {
                PhotosPicker(
                    selection: $photoVM.photosPickerItems,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(Color(hex: "E8705A"))
                        Text("Tap to add photo")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "E8705A"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                Color(hex: "E8705A").opacity(0.4),
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                    )
                    .background(Color(hex: "FFF0EC").cornerRadius(16))
                }
                .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 7) {
            Button {
                if let template = storyVM.selectedTemplate {
                    storyVM.theme = template.styleContext.isEmpty ? template.title : template.styleContext
                }
                currentScreen = .loading
            } label: {
                HStack(spacing: 6) {
                    if photoVM.isAnalyzing {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("Generating...")
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text("Generate My Story")
                    }
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "FF8C6B"), Color(hex: "E86D4A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "FF8C6B").opacity(0.35), radius: 10, y: 4)
            }
            .disabled(photoVM.selectedImages.isEmpty)
            .opacity(photoVM.selectedImages.isEmpty ? 0.4 : 1)

            Text("Your photo stays private and is never stored")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Color(hex: "B8B3AC"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 34)
    }
}
#Preview("ContentView") {
    ContentView()
}
