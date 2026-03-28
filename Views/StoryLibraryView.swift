import SwiftUI

struct StoryLibraryView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var selectedFilter: String = "All"

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var filteredTemplates: [StoryTemplate] {
        let all = StoryTemplate.samples
        switch selectedFilter {
        case "All": return all
        case "New": return all.filter { $0.isNew }
        case "World": return all.filter { $0.category == "World" }
        case "Feelings": return all.filter { $0.category == "Feelings" }
        case "Learn": return all.filter { $0.category == "Learn" }
        case "Seasonal": return all.filter { $0.category == "Seasonal" }
        default: return all
        }
    }

    private var newThisWeek: [StoryTemplate] { filteredTemplates.filter { $0.isNew } }
    private var thisMonthThemes: [StoryTemplate] { filteredTemplates.filter { !$0.isNew } }

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                scrollContent
                smTabBar(active: .storyTemplates, currentScreen: $currentScreen)
            }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Spacer()
            Text("Story Library")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1A1814"))
            Spacer()
        }
        .frame(height: 48)
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("UPDATED WEEKLY")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "A09890"))
                    .tracking(0.8)

                Text("Ready-made\nadventures")
                    .font(.custom("Georgia-Bold", size: 28))
                    .foregroundColor(Color(hex: "F2C94C"))
                    .padding(.top, 8)

                Text(subtitleText)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color(hex: "A09890"))
                    .lineSpacing(3)
                    .padding(.top, 12)
            }

            Spacer()

            // Decorative 4-pointed star
            Image(systemName: "staroflife.fill")
                .font(.system(size: 52, weight: .thin))
                .foregroundColor(Color(hex: "333333"))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "1A1814"))
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }

    private var subtitleText: String {
        let name = storyVM.childName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            return "Pick a story, add your\nchild's face — done in 30s"
        }
        return "Pick a story, add \(name)'s\nface — done in 30s"
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StoryTemplate.allCategories, id: \.self) { chip in
                    filterChip(chip)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(_ label: String) -> some View {
        let isActive = selectedFilter == label
        let isNewChip = label == "New"

        let chipColor: Color = isActive ? .white : isNewChip ? .white : Color(hex: "5C5750")
        let chipBg: Color = isActive ? Color(hex: "E8705A") : isNewChip ? Color(hex: "1A1814") : Color(hex: "F0EBE4")

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedFilter = label }
        } label: {
            HStack(spacing: 4) {
                if let iconName = StoryTemplate.categoryIcons[label] {
                    Image(systemName: iconName)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(chipColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(chipBg)
            .clipShape(Capsule())
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                heroBanner
                filterBar

                if !newThisWeek.isEmpty {
                    sectionLabel("NEW THIS WEEK")
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(newThisWeek) { template in
                            templateCard(template: template)
                        }
                    }
                    .padding(.horizontal, 18)
                }

                if !thisMonthThemes.isEmpty {
                    sectionLabel("THIS MONTH'S THEMES")
                        .padding(.top, newThisWeek.isEmpty ? 0 : 4)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(thisMonthThemes) { template in
                            templateCard(template: template)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "A09890"))
            .tracking(0.5)
            .padding(.horizontal, 18)
    }

    // MARK: - Template Card

    private func templateCard(template: StoryTemplate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: template.coverGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay(
                        Image(systemName: template.coverIcon)
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    )

                if template.isNew {
                    Text("New")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "E8705A"))
                        .clipShape(Capsule())
                        .padding(8)
                } else if template.isPro {
                    Text("Pro")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "1A1814"))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1A1814"))
                    .lineLimit(1)

                Text(template.category)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "A09890"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "F0EBE4"))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color(hex: "E8D9C8").opacity(0.35), radius: 10, y: 5)
        .onTapGesture {
            storyVM.selectedTemplate = template
            storyVM.previousScreen = .storyLibrary
            currentScreen = .templatePreview
        }
    }
}
