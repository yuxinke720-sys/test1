import SwiftUI
import UIKit

/// Reads a finished Growth Book page by page and exports it as PDF or images.
struct GrowthBookReaderView: View {
    @ObservedObject var growthVM: GrowthBookViewModel
    @Binding var currentScreen: AppScreen

    @State private var pageIndex = 0
    @State private var shareItems: [Any]?
    @State private var isExporting = false

    var body: some View {
        ZStack {
            Color(hex: "2A2622").ignoresSafeArea()

            if let book = growthVM.selectedBook {
                let pages = GrowthBookPage.pages(for: book)
                VStack(spacing: 0) {
                    topBar(book)

                    TabView(selection: $pageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { i, page in
                            ScaledPage(book: book, page: page)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    Text("\(pageIndex + 1) / \(pages.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 10)

                    bottomBar(book)
                }
                .overlay {
                    if isExporting {
                        ZStack {
                            Color.black.opacity(0.4).ignoresSafeArea()
                            ProgressView("Preparing…").tint(.white).foregroundColor(.white)
                                .padding(24).background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.6)))
                        }
                    }
                }
            } else {
                Button("Back") { currentScreen = .create }.foregroundColor(.white)
            }
        }
        #if DEBUG
        // QA: `-debugReaderPage N` opens page N; `-debugExportPDF YES` writes the PDF and logs its path.
        .onAppear {
            let d = UserDefaults.standard
            pageIndex = d.integer(forKey: "debugReaderPage")
            if d.bool(forKey: "debugExportPDF"), let book = growthVM.selectedBook, let url = growthVM.exportPDF(for: book) {
                print("[GrowthReader] DEBUG exported PDF: \(url.path)")
            }
        }
        #endif
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ActivityView(items: shareItems ?? [])
                .presentationDetents([.medium, .large])
        }
    }

    private func topBar(_ book: GrowthBook) -> some View {
        HStack {
            Button { currentScreen = .create } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            Spacer()
            Text(book.title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Button { currentScreen = .growthBook } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .accessibilityLabel("Timeline")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func bottomBar(_ book: GrowthBook) -> some View {
        HStack(spacing: 10) {
            exportButton("PDF", icon: "doc.richtext") {
                if let url = growthVM.exportPDF(for: book) { shareItems = [url] }
            }
            exportButton("Images", icon: "photo.on.rectangle") {
                let urls = growthVM.exportImages(for: book)
                if !urls.isEmpty { shareItems = urls }
            }
            Button {} label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.2.wave.2.fill").font(.system(size: 16, weight: .bold))
                    Text("Post · Soon").font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
            }
            .disabled(true)
            .accessibilityLabel("Post to Community, coming soon")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func exportButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            isExporting = true
            // Let the spinner render before the (synchronous) page rendering starts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                action()
                isExporting = false
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold))
                Text("Export \(title)").font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.12)))
        }
    }
}

/// Fits the fixed-size page design into whatever space is available.
private struct ScaledPage: View {
    let book: GrowthBook
    let page: GrowthBookPage

    var body: some View {
        GeometryReader { proxy in
            let size = GrowthBookPageView.pageSize
            let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
            GrowthBookPageView(book: book, page: page)
                .scaleEffect(scale)
                .frame(width: size.width * scale, height: size.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// UIKit share sheet (PDF / image files → Files, Photos, AirDrop, WeChat…).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
