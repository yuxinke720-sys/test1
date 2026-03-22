import SwiftUI
import PhotosUI

struct PhotoUploadView: View {
    @ObservedObject var storyVM: StoryViewModel
    @ObservedObject var photoVM: PhotoViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                progressBar(step: 1, total: 2, fill: 0.5)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        privacyBanner
                        titleSection
                        tipsCard
                        photoGrid
                        photoCount
                    }
                    .frame(maxWidth: .infinity)
                }

                bottomZone
            }
        }
        .onChange(of: photoVM.photosPickerItems) {
            Task { await photoVM.loadPhotos() }
        }
    }

    private var navBar: some View {
        HStack {
            Button { currentScreen = .home } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "FF8C6B"))
                    .frame(width: 36)
            }
            Spacer()
            Text("New Story").font(.system(size: 17, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
            Spacer()
            Color.clear.frame(width: 36)
        }
        .frame(height: 48).padding(.horizontal, 18)
    }

    private var privacyBanner: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "2A8A40"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Your photos stay private").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "2A8A40"))
                Text("Used only to illustrate your story. Never stored, shared, or used to train AI.")
                    .font(.system(size: 10)).foregroundColor(Color(hex: "3A8050")).lineSpacing(2)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(hex: "E8F8EE")).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "C4EAC9"), lineWidth: 1))
        .padding(.horizontal, 18).padding(.bottom, 12)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Add photos of \(storyVM.childName)").font(.system(size: 20, weight: .black)).foregroundColor(Color(hex: "1E1C1A"))
            Text("1–10 photos · Clear face shots work best").font(.system(size: 12)).foregroundColor(Color(hex: "7A756E"))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 10)
    }

    private var tipsCard: some View {
        HStack {
            tipItem(icon: "face.smiling.inverse", label: "Clear face"); Spacer()
            tipItem(icon: "sun.max.fill", label: "Good light"); Spacer()
            tipItem(icon: "figure.stand", label: "Natural pose"); Spacer()
            tipItem(icon: "eyeglasses", label: "No sunglasses")
        }
        .padding(10).background(Color(hex: "FFFEF5")).cornerRadius(12)
        .padding(.horizontal, 18).padding(.bottom, 14)
    }

    private func tipItem(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "C89F00"))
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "C89F00"))
        }
    }

    private var photoGrid: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 7
            let hp: CGFloat = 36
            let cellSize = (geo.size.width - hp - spacing * 2) / 3

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: 3), spacing: spacing) {
                ForEach(Array(photoVM.selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: cellSize, height: cellSize).clipped().cornerRadius(11)
                        Button { photoVM.removePhoto(at: index) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                .frame(width: 22, height: 22).background(Color(hex: "FF5252")).clipShape(Circle())
                        }.padding(5)
                    }
                    .frame(width: cellSize, height: cellSize)
                }

                let totalVis = max(6, photoVM.selectedImages.count + 1)
                let empty = max(0, min(photoVM.maxPhotos, totalVis) - photoVM.selectedImages.count)
                if empty > 0 {
                    ForEach(0..<empty, id: \.self) { _ in
                        PhotosPicker(selection: $photoVM.photosPickerItems,
                                     maxSelectionCount: photoVM.maxPhotos - photoVM.selectedImages.count, matching: .images) {
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(Color(hex: "FFE94A"), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .frame(width: cellSize, height: cellSize)
                                .background(Color(hex: "FFFEF5").cornerRadius(11))
                                .overlay(VStack(spacing: 3) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(Color(hex: "FFE94A"))
                                    Text("Add").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "F5C800"))
                                })
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: gridHeight)
        .animation(.spring(response: 0.3), value: photoVM.selectedImages.count)
    }

    private var gridHeight: CGFloat {
        let total = max(6, photoVM.selectedImages.count + 1)
        let count = min(photoVM.maxPhotos, total)
        return CGFloat(ceil(Double(count) / 3.0)) * 117 + 10
    }

    private var photoCount: some View {
        HStack(spacing: 4) {
            Text(photoVM.photoCountText).font(.system(size: 11)).foregroundColor(Color(hex: "7A756E"))
            Text("·").foregroundColor(Color(hex: "7A756E"))
            Text(photoVM.statusText).font(.system(size: 11, weight: .bold))
                .foregroundColor(photoVM.canContinue ? Color(hex: "2A8A40") : Color(hex: "FF8C6B"))
        }.padding(.vertical, 10)
    }

    private var bottomZone: some View {
        VStack(spacing: 7) {
            Button {
                Task { await photoVM.analyzePhotos(); currentScreen = .storySetup }
            } label: {
                HStack(spacing: 6) {
                    if photoVM.isAnalyzing { ProgressView().tint(.white).scaleEffect(0.8); Text("Analyzing…") }
                    else {
                        Text("Analyze & Continue")
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                    }
                }
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(LinearGradient(colors: [Color(hex: "FF8C6B"), Color(hex: "E86D4A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "FF8C6B").opacity(0.35), radius: 10, y: 4)
            }
            .disabled(!photoVM.canContinue || photoVM.isAnalyzing)
            .opacity(photoVM.canContinue ? 1 : 0.4)

            Text("Photos deleted from our servers after generation")
                .font(.system(size: 10)).foregroundColor(Color(hex: "B8B3AC"))
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 34)
    }
}

func progressBar(step: Int, total: Int, fill: Double) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: "E0DBD4"))
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(hex: "FFD93D"), Color(hex: "FFE94A")], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * fill)
                    .animation(.easeInOut(duration: 0.4), value: fill)
            }
        }.frame(height: 5)
        Text("Step \(step) of \(total)").font(.system(size: 10, weight: .regular)).foregroundColor(Color(hex: "7A756E"))
    }
    .padding(.horizontal, 18).padding(.bottom, 10)
}
