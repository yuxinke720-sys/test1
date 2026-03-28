import SwiftUI

struct StoryCalendarView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Title Bar
                VStack(spacing: 4) {
                    HStack {
                        Button {
                            currentScreen = .home
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "E8705A"))
                                .frame(width: 36, height: 36)
                        }
                        Spacer()
                        Text("Story Calendar")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "1A1814"))
                        Spacer()
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 18)

                    Text("Full calendar view — tap a day to see the story")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "A09890"))
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)

                // MARK: - Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        calendarCard
                        entriesList
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }

                smTabBar(active: .home, currentScreen: $currentScreen)
            }
        }
    }

    // MARK: - Calendar Card
    private var calendarCard: some View {
        VStack(spacing: 0) {
            // Month navigation
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "E8705A"))
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "FFF0EC").cornerRadius(10))
                }
                Spacer()
                Text(monthYearString(displayedMonth))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1A1814"))
                Spacer()
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "E8705A"))
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "FFF0EC").cornerRadius(10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Weekday labels
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(
                            label == "Sun" || label == "Sat"
                                ? Color(hex: "D4A07A")
                                : Color(hex: "A09890")
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            // Day grid
            let days = calendarDays()
            let storyDaysMap = storyVM.storyDays(for: displayedMonth)
            let todayDay = todayDayNumber()
            let currentMonth = isCurrentMonth()

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(days) { item in
                    if let day = item.day {
                        let hasStory = storyDaysMap[day] != nil
                        let isToday = day == todayDay && currentMonth

                        calendarDayCell(day: day, hasStory: hasStory, isToday: isToday)
                            .onTapGesture {
                                if let story = storyDaysMap[day] {
                                    storyVM.currentStory = story
                                    storyVM.currentPage = 0
                                    storyVM.markAsRead(story)
                                    currentScreen = .storybook
                                } else {
                                    currentScreen = .storyCalendar
                                }
                            }
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Color(hex: "E8705A"), label: "Has story")
                legendDot(color: Color(hex: "1A1814"), label: "Today")
            }
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white)
                .shadow(color: Color(hex: "E8D9C8").opacity(0.4), radius: 14, y: 6)
        )
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Day Cell
    private func calendarDayCell(day: Int, hasStory: Bool, isToday: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(day)")
                .font(.system(size: 14, weight: isToday ? .black : hasStory ? .bold : .medium,
                              design: .rounded))
                .foregroundColor(
                    isToday ? .white :
                    hasStory ? Color(hex: "7A6200") :
                    Color(hex: "5C5750")
                )

            Circle()
                .fill(
                    isToday && hasStory ? Color.white.opacity(0.9) :
                    hasStory ? Color(hex: "E8705A") :
                    Color.clear
                )
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isToday
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "FF8C6B"), Color(hex: "E8705A")],
                            startPoint: .top, endPoint: .bottom))
                        : hasStory
                            ? AnyShapeStyle(Color(hex: "FFF8E7"))
                            : AnyShapeStyle(Color(hex: "FAF6F1"))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    hasStory && !isToday ? Color(hex: "FFE4B5").opacity(0.7) : Color.clear,
                    lineWidth: 1
                )
        )
        .shadow(
            color: isToday ? Color(hex: "E8705A").opacity(0.3) : .clear,
            radius: isToday ? 5 : 0, y: isToday ? 3 : 0
        )
    }

    // MARK: - Legend Dot
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "A09890"))
        }
    }

    // MARK: - Entries List
    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This month")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1A1814"))
                .padding(.horizontal, 18)

            let monthStories = storiesForDisplayedMonth()

            if monthStories.isEmpty {
                emptyState
            } else {
                ForEach(monthStories) { story in
                    calendarEntryRow(story: story)
                        .onTapGesture {
                            storyVM.currentStory = story
                            storyVM.currentPage = 0
                            storyVM.markAsRead(story)
                            currentScreen = .storybook
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 12)

            Image(systemName: "book.closed")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Color(hex: "D4CFC8"))

            Text("No stories this month yet")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "A09890"))

            Text("Create a story and it will appear here")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "C4BFB8"))

            Spacer().frame(height: 4)

            Button {
                currentScreen = .photoUpload
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Create Story")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: "FF8C6B"), Color(hex: "E8705A")],
                            startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: Color(hex: "E8705A").opacity(0.3), radius: 6, y: 3)
            }

            Spacer().frame(height: 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Entry Row
    private func calendarEntryRow(story: Story) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: story.createdAt))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1A1814"))
                Text(shortMonthString(story.createdAt))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "A09890"))
                    .textCase(.uppercase)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(story.title.isEmpty ? "Untitled Story" : story.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "1A1814"))
                    .lineLimit(1)
                Text("\(story.style.rawValue) story")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "A09890"))
            }

            Spacer()

            Text(story.style.emoji)
                .font(.system(size: 22))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color(hex: "E8D9C8").opacity(0.25), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "F0EBE4"), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    // MARK: - Helpers

    private struct IndexedDay: Identifiable {
        let offset: Int
        let day: Int?
        var id: Int { offset }
    }

    private func calendarDays() -> [IndexedDay] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmpty = weekday - 1

        var result: [IndexedDay] = []
        for i in 0..<leadingEmpty {
            result.append(IndexedDay(offset: i, day: nil))
        }
        for day in range {
            result.append(IndexedDay(offset: leadingEmpty + day - 1, day: day))
        }
        let remainder = result.count % 7
        if remainder > 0 {
            let start = result.count
            for i in 0..<(7 - remainder) {
                result.append(IndexedDay(offset: start + i, day: nil))
            }
        }
        return result
    }

    private func todayDayNumber() -> Int {
        calendar.component(.day, from: Date())
    }

    private func isCurrentMonth() -> Bool {
        let now = Date()
        return calendar.component(.year, from: displayedMonth) == calendar.component(.year, from: now)
            && calendar.component(.month, from: displayedMonth) == calendar.component(.month, from: now)
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func shortMonthString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func storiesForDisplayedMonth() -> [Story] {
        storyVM.savedStories.filter { story in
            calendar.component(.year, from: story.createdAt) == calendar.component(.year, from: displayedMonth)
            && calendar.component(.month, from: story.createdAt) == calendar.component(.month, from: displayedMonth)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}

#Preview("StoryCalendarView") {
    StoryCalendarView(storyVM: StoryViewModel(), currentScreen: .constant(.storyCalendar))
}
