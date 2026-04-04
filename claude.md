# StoryMe

## Stack
iOS 17+ / Swift 5.9 / SwiftUI / MVVM / Gemini API

## Architecture
- Models: `Story`, `StoryPage`, `StoryTemplate` (all Codable)
- ViewModels: `StoryViewModel` (@MainActor), `PhotoViewModel`
- Services: `GeminiService` (text via gemini-2.0-flash, images via Imagen 3)
- State: `@AppStorage` for screen persistence, `UserDefaults` for stories
- API key: `Secrets.xcconfig` → Info.plist `$(GEMINI_API_KEY)` → Bundle.main

## Design System
- Background: `F7F3ED`, Accent: `E8705A`, Text: `1E1C1A`
- Fonts: `.system(design: .rounded)` throughout
- Cards: white background, `cornerRadius(18)`, soft shadow `E8D9C8`

## Rules
- No hardcoded dimensions for layout containers. Use `maxWidth: .infinity`, `Spacer`, ScrollView.
- Background colors use `.ignoresSafeArea()`. Content respects safe areas naturally.
- Tab bar bottom handled by `.ignoresSafeArea(edges: .bottom)` on background.
- View files under 200 lines. Extract subviews for complex screens.
- MVVM: Views bind data only. Logic in ViewModels.
- Generation starts from `LoadingView.onAppear`, never from departing views.
- `Secrets.xcconfig` is in `.gitignore`. Never hardcode API keys.
