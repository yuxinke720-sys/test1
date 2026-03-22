import SwiftUI
import PhotosUI

struct PhotoUploadView: View {
    @ObservedObject var storyVM: StoryViewModel
    @ObservedObject var photoVM: PhotoViewModel
    @Binding var currentScreen: AppScreen

    @State private var showingImagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            navBar

            // Progress bar
            progressBar(step: 1, total: 2, fill: 0.5)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    privacyBanner
                    titleSection
                    tipsCard
                    photoGrid
                    photoCount
                }
            }

            bottomZone
        }
        .background(Color.white.ignoresSafeArea())
        .onChange(of: photoVM.photosPickerItems) {
            Task { await photoVM.loadPhotos() }
        }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button {
                currentScreen = .home
            } label: {
                Text("←")
                    .font(.system(size: 22))
                    .foregroundColor(.smCoral400)
                    .frame(width: 36)
            }
            Spacer()
            Text("New Story")
                .font(.custom("Nunito-ExtraBold", size: 17))
                .foregroundColor(.smTextPrimary)
            Spacer()
            Color.clear.frame(width: 36)
        }
        .frame(height: 48)
        .padding(.horizontal, 18)
    }

    // MARK: - Privacy Banner
    private var privacyBanner: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("🔒").font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text("Your photos stay private")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.smGreen600)
                Text("Used only to illustrate your story. Never stored, shared, or used to train AI.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "3A8050"))
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.smGreen100)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "C4EAC9"), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Title
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Add photos of \(storyVM.childName)")
                .font(.custom("Nunito-Black", size: 20))
                .foregroundColor(.smTextPrimary)
            Text("1–10 photos · Clear face shots work best")
                .font(.system(size: 12))
                .foregroundColor(.smTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    // MARK: - Tips Card
    private var tipsCard: some View {
        HStack {
            tipItem(emoji: "😊", label: "Clear face")
            Spacer()
            tipItem(emoji: "☀️", label: "Good light")
            Spacer()
            tipItem(emoji: "📸", label: "Natural pose")
            Spacer()
            tipItem(emoji: "🚫", label: "No sunglasses")
        }
        .padding(10)
        .background(Color.smYellow50)
        .cornerRadius(12)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private func tipItem(emoji: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 20))
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.smYellow600)
        }
    }

    // MARK: - Photo Grid
    private var photoGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 7
            let columns: CGFloat = 3
            let totalSpacing = spacing * (columns - 1)
            let horizontalPadding: CGFloat = 18 * 2
            let cellSize = (geo.size.width - horizontalPadding - totalSpacing) / columns

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: 3),
                spacing: spacing
            ) {
                // Filled cells — each image forced to exact square
                ForEach(Array(photoVM.selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cellSize, height: cellSize)
                            .clipped()
                            .cornerRadius(11)

                        // Delete button — always visible on every cell
                        Button {
                            photoVM.removePhoto(at: index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.smRed400)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        }
                        .padding(5)
                    }
                    .frame(width: cellSize, height: cellSize)
                    .transition(.scale.combined(with: .opacity))
                }

                // Empty cells — fill to at least 6 total, up to remaining slots
                let totalVisible = max(6, photoVM.selectedImages.count + 1)
                let emptyCells = max(0, min(photoVM.maxPhotos, totalVisible) - photoVM.selectedImages.count)
                if emptyCells > 0 {
                    ForEach(0..<emptyCells, id: \.self) { _ in
                        PhotosPicker(
                            selection: $photoVM.photosPickerItems,
                            maxSelectionCount: photoVM.maxPhotos - photoVM.selectedImages.count,
                            matching: .images
                        ) {
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(Color.smYellow300, style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .frame(width: cellSize, height: cellSize)
                                .background(Color.smYellow50.cornerRadius(11))
                                .overlay(
                                    VStack(spacing: 3) {
                                        Text("📷")
                                            .font(.system(size: 20))
                                            .foregroundColor(.smYellow300)
                                        Text("Add")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.smYellow500)
                                    }
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: photoGridHeight)
        .animation(.spring(response: 0.3), value: photoVM.selectedImages.count)
    }

    /// Calculate grid height based on number of rows
    private var photoGridHeight: CGFloat {
        let totalVisible = max(6, photoVM.selectedImages.count + 1)
        let cellCount = min(photoVM.maxPhotos, totalVisible)
        let rows = ceil(Double(cellCount) / 3.0)
        // Estimate: each cell ~110pt + 7pt spacing per row
        return CGFloat(rows) * 117 + 10
    }

    // MARK: - Photo Count
    private var photoCount: some View {
        HStack(spacing: 4) {
            Text(photoVM.photoCountText)
                .font(.system(size: 11))
                .foregroundColor(.smTextSecondary)
            Text("·")
                .foregroundColor(.smTextSecondary)
            Text(photoVM.statusText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(photoVM.canContinue ? .smGreen600 : .smCoral400)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Bottom Zone
    private var bottomZone: some View {
        VStack(spacing: 7) {
            Button {
                Task {
                    await photoVM.analyzePhotos()
                    currentScreen = .storySetup
                }
            } label: {
                HStack(spacing: 6) {
                    if photoVM.isAnalyzing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Analyzing…")
                    } else {
                        Text("Analyze & Continue →")
                    }
                }
                .font(.custom("Nunito-ExtraBold", size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.smCoral400, .smCoral500],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .smCoral400.opacity(0.35), radius: 10, y: 4)
            }
            .disabled(!photoVM.canContinue || photoVM.isAnalyzing)
            .opacity(photoVM.canContinue ? 1 : 0.4)

            Text("Photos deleted from our servers after generation")
                .font(.system(size: 10))
                .foregroundColor(.smNeutral300)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

// MARK: - Shared progress bar component
func progressBar(step: Int, total: Int, fill: Double) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.smNeutral200)
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [.smYellow400, .smYellow300],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * fill)
                    .animation(.easeInOut(duration: 0.4), value: fill)
            }
        }
        .frame(height: 5)

        Text("Step \(step) of \(total)")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.smTextSecondary)
    }
    .padding(.horizontal, 18)
    .padding(.bottom, 10)
}
#Preview {
    PhotoUploadView(
        storyVM: StoryViewModel(),
        photoVM: PhotoViewModel(),
        currentScreen: .constant(.photoUpload)
    )
}
