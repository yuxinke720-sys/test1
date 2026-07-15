import SwiftUI
import PhotosUI

/// Timeline of an in-progress Growth Book: add / edit chapters, set privacy,
/// and finish the book (which plays the completion ceremony).
struct GrowthBookDetailView: View {
    @ObservedObject var growthVM: GrowthBookViewModel
    @Binding var currentScreen: AppScreen

    @State private var editingChapter: GrowthChapter?
    @State private var confirmComplete = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            Color.smBackground.ignoresSafeArea()

            if let book = growthVM.selectedBook {
                VStack(spacing: 0) {
                    topBar(book)
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            headerCard(book)
                            timeline(book)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                    if !book.isCompleted { bottomBar(book) }
                }
                .sheet(item: $editingChapter) { chapter in
                    GrowthChapterEditor(growthVM: growthVM, book: book, chapter: chapter)
                }
                .alert("Did \(book.childName) make it?", isPresented: $confirmComplete) {
                    Button("Not yet", role: .cancel) {}
                    Button("Yes, finish the book!") {
                        withAnimation { growthVM.completeBook(book.id) }
                    }
                } message: {
                    Text("\"\(book.goal)\"\n\nFinishing locks the book — no more chapters can be added — and turns it into a complete picture book.")
                }
                .alert("Delete this growth book?", isPresented: $confirmDelete) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        growthVM.deleteBook(book.id)
                        currentScreen = .create
                    }
                } message: {
                    Text("All chapters and photos in \"\(book.title)\" will be removed from this device.")
                }

                if growthVM.celebratingBookID == book.id {
                    CompletionCeremonyView(book: book) {
                        growthVM.celebratingBookID = nil
                        currentScreen = .growthReader
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
            } else {
                missingBook
            }
        }
    }

    // MARK: - Top bar

    private func topBar(_ book: GrowthBook) -> some View {
        HStack {
            Button { currentScreen = .create } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.smCoral500)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Text("Growth Book")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.smTextPrimary)
            Spacer()
            Menu {
                if book.isCompleted {
                    Button { currentScreen = .growthReader } label: { Label("Open book", systemImage: "book") }
                }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete book", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.smTextSecondary)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Header

    private func headerCard(_ book: GrowthBook) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                GrowthCoverThumb(book: book).frame(width: 76, height: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(.smTextPrimary)
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "flag.checkered").font(.system(size: 11, weight: .bold))
                        Text(book.goal).font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.smTextSecondary)
                    HStack(spacing: 12) {
                        stat(book.isCompleted ? "Done" : "Day \(book.dayCount)", icon: book.isCompleted ? "checkmark.seal.fill" : "calendar")
                        stat("\(book.chapters.count) chapters", icon: "book.pages")
                        stat("\(book.mediaCount)", icon: "photo")
                    }
                    .padding(.top, 2)
                }
            }
            visibilityMenu(book)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private func stat(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text).font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(.smCoral500)
    }

    private func visibilityMenu(_ book: GrowthBook) -> some View {
        Menu {
            ForEach(BookVisibility.allCases) { v in
                Button {
                    growthVM.setVisibility(v, for: book.id)
                } label: {
                    Label(v.label, systemImage: book.visibility == v ? "checkmark" : v.sfSymbol)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: book.visibility.sfSymbol).font(.system(size: 12, weight: .bold))
                Text("Who can see this: \(book.visibility.label)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(book.visibility == .privateOnly ? .smTextSecondary : .smCoral500)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.smNeutral100))
        }
        .overlay(alignment: .bottomLeading) {
            if book.visibility != .privateOnly {
                Text("Sharing opens with Community — for now this book stays on your device.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.smTextSecondary)
                    .offset(y: 18)
            }
        }
        .padding(.bottom, book.visibility != .privateOnly ? 14 : 0)
    }

    // MARK: - Timeline

    @ViewBuilder
    private func timeline(_ book: GrowthBook) -> some View {
        let chapters = book.sortedChapters
        if chapters.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 30)).foregroundColor(.smYellow500)
                Text("Chapter 1 starts today")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.smTextPrimary)
                Text("Add the first try — even if it didn't work yet. Those moments make the best pages.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.smTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("TIMELINE")
                    .font(.system(size: 10, weight: .bold)).tracking(0.7)
                    .foregroundColor(.smTextSecondary)
                    .padding(.bottom, 10)
                ForEach(Array(chapters.enumerated()), id: \.element.id) { i, chapter in
                    timelineRow(chapter, number: i + 1, isLast: i == chapters.count - 1, book: book)
                }
                if book.isCompleted, let done = book.completedAt {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundColor(.smGreen400).frame(width: 24)
                        Text("Goal reached · \(done.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.smGreen400)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func timelineRow(_ chapter: GrowthChapter, number: Int, isLast: Bool, book: GrowthBook) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.smCoral400)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .padding(.top, 16)
                Rectangle()
                    .fill(Color.smCoral300.opacity(0.6))
                    .frame(width: 2)
                    .opacity(isLast && !book.isCompleted ? 0 : 1)
            }
            .frame(width: 24)

            Button {
                if !book.isCompleted { editingChapter = chapter }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CHAPTER \(number)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1)
                            .foregroundColor(.smCoral500)
                        Spacer()
                        Text(chapter.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.smTextSecondary)
                    }
                    if !chapter.title.isEmpty {
                        Text(chapter.title)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.smTextPrimary)
                    }
                    if !chapter.note.isEmpty {
                        Text(chapter.note)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color(hex: "3A342E"))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    if !chapter.media.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chapter.media) { m in MediaThumb(media: m).frame(width: 72, height: 72) }
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .contextMenu {
                if !book.isCompleted {
                    Button { editingChapter = chapter } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { growthVM.deleteChapter(chapter.id, in: book.id) } label: { Label("Delete chapter", systemImage: "trash") }
                }
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Bottom bar

    private func bottomBar(_ book: GrowthBook) -> some View {
        HStack(spacing: 10) {
            Button {
                editingChapter = GrowthChapter(date: Date())
            } label: {
                Label("Add Chapter", systemImage: "plus")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color.smCoral400))
            }
            Button {
                confirmComplete = true
            } label: {
                Label("Complete", systemImage: "flag.checkered")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(book.chapters.isEmpty ? Color(hex: "B8B3AC") : .smGreen400)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 18)
                    .background(Capsule().stroke(book.chapters.isEmpty ? Color(hex: "E0DCD6") : Color.smGreen400, lineWidth: 2))
            }
            .disabled(book.chapters.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.smBackground.shadow(color: .black.opacity(0.05), radius: 6, y: -2).ignoresSafeArea(edges: .bottom))
    }

    private var missingBook: some View {
        VStack(spacing: 14) {
            Text("This book isn't available.").foregroundColor(.smTextSecondary)
            Button("Back to Create") { currentScreen = .create }.foregroundColor(.smCoral500)
        }
    }
}

// MARK: - Media thumbnail

struct MediaThumb: View {
    let media: ChapterMedia

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.smNeutral100
                .overlay {
                    if let image = ImageStorageService.shared.loadImageSync(from: media.path) {
                        Image(uiImage: GrowthBookViewModel.resized(image, maxSide: 300)).resizable().scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if media.kind == .aiIllustration {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color.smCoral400))
                    .padding(4)
            }
        }
    }
}

// MARK: - Chapter editor

struct GrowthChapterEditor: View {
    @ObservedObject var growthVM: GrowthBookViewModel
    let book: GrowthBook
    @State var chapter: GrowthChapter

    @Environment(\.dismiss) private var dismiss
    @State private var pickerItems: [PhotosPickerItem] = []
    /// Files created during this editing session — removed again on Cancel.
    @State private var addedMedia: [ChapterMedia] = []
    @State private var isImporting = false

    private var isNew: Bool { !book.chapters.contains { $0.id == chapter.id } }
    private var chapterNumber: Int {
        (book.sortedChapters.firstIndex { $0.id == chapter.id } ?? book.chapters.count) + 1
    }
    private var canSave: Bool {
        !chapter.title.trimmingCharacters(in: .whitespaces).isEmpty
            || !chapter.note.trimmingCharacters(in: .whitespaces).isEmpty
            || !chapter.media.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DatePicker("Date", selection: $chapter.date, in: ...Date(), displayedComponents: .date)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tint(.smCoral400)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))

                    VStack(alignment: .leading, spacing: 8) {
                        label("Headline")
                        TextField("e.g. First try with the jacket", text: $chapter.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("What happened?")
                        TextField("The sleeves kept getting stuck, but she laughed and tried again…", text: $chapter.note, axis: .vertical)
                            .lineLimit(4...10)
                            .font(.system(size: 15, design: .rounded))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                    }

                    mediaSection
                }
                .padding(20)
            }
            .background(Color.smBackground.ignoresSafeArea())
            .navigationTitle(isNew ? "Chapter \(chapterNumber)" : "Edit Chapter \(chapterNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(!addedMedia.isEmpty || !growthVM.illustratingMediaIDs.isEmpty)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        growthVM.discardMedia(addedMedia)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave || !growthVM.illustratingMediaIDs.isEmpty)
                }
            }
            .onChange(of: pickerItems) { _, items in importPhotos(items) }
            .alert("Something went wrong", isPresented: Binding(
                get: { growthVM.errorMessage != nil },
                set: { if !$0 { growthVM.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(growthVM.errorMessage ?? "")
            }
        }
    }

    // MARK: Media

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                label("Photos & drawings")
                Spacer()
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 9, matching: .images) {
                    Label("Add", systemImage: "photo.badge.plus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.smCoral500)
                }
            }
            if isImporting { ProgressView().frame(maxWidth: .infinity) }

            if chapter.media.isEmpty && !isImporting {
                Text("Add real photos or a snapshot of your child's drawing. Tap ✨ on a photo to turn it into a picture-book illustration.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.smTextSecondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(chapter.media) { media in mediaCell(media) }
            }

            if chapter.media.contains(where: { $0.kind == .photo }) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 11))
                    Text("✨ sends that one photo to our AI illustration service to draw it. The photo itself stays on this device.")
                        .font(.system(size: 11, design: .rounded))
                }
                .foregroundColor(.smTextSecondary)
            }
        }
    }

    private func mediaCell(_ media: ChapterMedia) -> some View {
        let isBusy = growthVM.illustratingMediaIDs.contains(media.id)
        let alreadyIllustrated = chapter.media.contains { $0.sourceMediaID == media.id }
        return MediaThumb(media: media)
            .frame(height: 100)
            .overlay {
                if isBusy {
                    ZStack {
                        Color.black.opacity(0.45)
                        VStack(spacing: 6) {
                            ProgressView().tint(.white)
                            Text("Painting…").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { remove(media) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .padding(4)
                .disabled(isBusy)
            }
            .overlay(alignment: .bottomLeading) {
                if media.kind == .photo && !alreadyIllustrated && !isBusy {
                    Button { illustrate(media) } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                            Text("Illustrate")
                        }
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Capsule().fill(Color.smCoral400))
                    }
                    .padding(5)
                }
            }
    }

    // MARK: Actions

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isImporting = true
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let media = growthVM.storePhoto(data, bookID: book.id) {
                    chapter.media.append(media)
                    addedMedia.append(media)
                }
            }
            pickerItems = []
            isImporting = false
        }
    }

    private func illustrate(_ photo: ChapterMedia) {
        Task {
            if let art = await growthVM.illustrate(photo: photo, chapterNote: chapter.note.isEmpty ? chapter.title : chapter.note, book: book) {
                let index = (chapter.media.firstIndex { $0.id == photo.id } ?? chapter.media.count - 1) + 1
                chapter.media.insert(art, at: min(index, chapter.media.count))
                addedMedia.append(art)
            }
        }
    }

    private func remove(_ media: ChapterMedia) {
        chapter.media.removeAll { $0.id == media.id }
        // Files added in this session can go right away; saved ones are removed on Save.
        if addedMedia.contains(where: { $0.id == media.id }) {
            growthVM.discardMedia([media])
            addedMedia.removeAll { $0.id == media.id }
        }
    }

    private func save() {
        // Delete files of previously-saved media the parent removed while editing.
        if let original = book.chapters.first(where: { $0.id == chapter.id }) {
            let kept = Set(chapter.media.map(\.id))
            growthVM.discardMedia(original.media.filter { !kept.contains($0.id) })
        }
        chapter.title = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        chapter.note = chapter.note.trimmingCharacters(in: .whitespacesAndNewlines)
        growthVM.saveChapter(chapter, in: book.id)
        dismiss()
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.smTextSecondary)
    }
}
