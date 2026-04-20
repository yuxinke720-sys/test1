# StoryMe - Workspace Guide & Rules

## 1. Project Context & Core Architecture
- **Product**: AI children's storybook generator.
- **Tech Stack**: iOS Native (Swift / SwiftUI), MVVM architecture.
- **AI Engine**: Google Gemini API (`Services/GeminiService.swift`).

## 2. The 4 Creation Modes (Business Logic)
When handling any generation logic, strictly adhere to the boundaries of these four modes:
- **Plan A (True Memory)**: User uploads coherent photos. AI restores and narrates the actual continuous events based on the faces and scenes in the real photos.
- **Plan C (Template Mall)**: Independent page system (`Views/StoryTemplateView.swift`). User selects a fixed plot (e.g., overcoming fear, making friends), and the AI only integrates the child's face into the preset story.
- **Plan B & D (Free Creation & Quick Fallback)**:
  - When Plan A conditions are not met (photos are incoherent or contain only faces), forcefully trigger **Plan D**, requiring the user to input a custom story description.
  - **Plan B Integration**: At the bottom of the Plan D input interface, provide tags for different story types. Clicking a tag automatically populates a specific style of Prompt (acting as a fallback and inspiration mechanism).

## 3. Key Business Modules Design Requirements
- **Story Calendar (`Views/StoryCalendarView.swift`)**:
  - The core achievement page. Must sync birthdays from the user Profile.
  - **Visual Markers**: True stories (Plan A) use coral dots; Template stories (Plan C) use blue dots; Today's story uses a dark background. Future important events (birthdays/school starting) are marked with dashed "upcoming" lines.
  - **Timestamp Logic**: Stories must be sorted by the "actual event date", NOT the "generation date".
  - **Interaction**: Allow users to long-press a date to add "growth notes" (e.g., first lost tooth) as Context for future AI generation.
- **Personalized Profile**: Supports personality tags (shy/active) and family member relationships. These traits must be automatically injected into the prompt when generating stories.

## 4. UI & Multi-Device Compatibility (CRITICAL)
All UI code must be strictly responsive to support all iPhone models (from iPhone SE to iPhone 15 Pro Max).
- **No Hardcoded Dimensions**: AVOID hardcoding fixed `width` or `height` values for major UI components.
- **Responsive Modifiers**: Use `.frame(maxWidth: .infinity, maxHeight: .infinity)`, `Spacer()`, and `VStack`/`HStack` proportions.
- **Dynamic Layouts**: Use `GeometryReader` or `ViewThatFits` for complex layouts that need to scale based on screen size.
- **Safe Area & Scrolling**: Always respect the `.safeAreaInset`. Ensure all content-heavy screens (like `HomeView` and `StorybookView`) are wrapped in `ScrollView` to prevent clipping on smaller screens.

## 5. Coding Conventions
- **UI Standards**: UI must be written in SwiftUI. Keep single View files under 200 lines. Complex pages (e.g., `HomeView`, `StorybookView`) MUST be split into Subviews.
- **Architecture**: Strict MVVM. Views only bind data; logic lives in `ViewModels`.
- **State Management**: Use `@StateObject` and `@ObservedObject` correctly to prevent memory leaks during navigation.

## 6. Skills & Automated Actions
- **[Skill: Mock UI Data]**: When asked to "test UI", automatically inject mock stories into `StoryViewModel` to verify rendering across different screen sizes. Ensure the mock data triggers the coral/blue dot logic in the calendar.
- **[Skill: Screen Size Test]**: When writing new UI components, automatically provide the Xcode preview code with `.previewDevice("iPhone SE (3rd generation)")` alongside the default preview.

## 7. Pre-Commit Hooks / Rules
- **UI Scaling Hook**: Before finalizing any SwiftUI view, explicitly check and confirm: "Will this layout overflow on a 4.7-inch screen?" If yes, rewrite using `ScrollView` or scalable frames.
- **Component Split Hook**: If a file exceeds 150 lines, pause and ask to extract Subviews.
