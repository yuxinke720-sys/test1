# Claude System Prompt for "StoryMe" iOS App

## Project Overview
**Project Name**: StoryMe
**Description**: An AI-powered personalized children's picture book generator.
**Current State**: MVP Prototype. High-fidelity SwiftUI UI is complete. Core AI text-to-image pipeline (Volcengine/Doubao) is implemented but requires stabilization and architectural refactoring before production.
**Primary Target**: Achieve a production-ready MVP for App Store submission (requires data persistence refactoring, backend security, and legal compliance).

## Tech Stack & Architecture
- **Platform**: iOS Native (iOS 16.0+)
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (Strict declarative UI)
- **Concurrency**: Swift Concurrency (`async/await`, `Task`, `TaskGroup`)
- **Architecture**: MVVM (Model-View-ViewModel) + Singleton Services
- **AI Models**: Volcengine Doubao (Text: `/chat/completions`, Image: `/images/generations`)

##  CRITICAL DIRECTIVES & TECHNICAL DEBT (DO NOT IGNORE)

### 1. Data Storage Rules (Highest Priority)
- **NEVER** use `UserDefaults` to store large datasets, `Story` arrays, or `imageData` (Base64/Binary). 
- **CURRENT MIGRATION TASK**: We are migrating away from the legacy `UserDefaults` approach. 
- **IMAGE STORAGE**: All generated AI images must be saved to the local file system (`FileManager` -> `Documents` directory). The `Story` model should only store the file path/URL, NOT the binary data.
- **DATABASE**: Use standard iOS persistence (prepare for SwiftData or CoreData) for structured story data.

### 2. Networking & AI Service Rules (`AIService.swift`)
- **NO SILENT FAILURES**: When concurrent image generation fails, do not silently return `nil` without logging the exact HTTP status and error.
- **RESILIENCE**: Implement retry mechanisms (with exponential backoff) for AI API calls. Handle rate limits and timeouts gracefully.
- **SECURITY AWARENESS**: API Keys are currently hardcoded for prototyping. Any new architecture design must assume API Keys will be moved to a remote Backend service.

### 3. MVVM Strict Boundaries
- **Views**: Must be "dumb". Only handle UI rendering, animations, and user interactions. Do not put business logic or API calls here.
- **ViewModels**: Must be annotated with `@MainActor`. Handle all state changes, data formatting, and bridging between Views and Services.
- **Services**: Pure logic, networking, and data fetching. Independent of UI.

### 4. App Store Compliance (Kids Category)
- Keep in mind that this app targets children (3-6 years old).
- Any new feature must consider COPPA compliance.
- UI flows must support Parental Gates (e.g., math problems before IAP or settings) and mandatory Privacy Policy agreements.

##  AI Assistant Behavior Guidelines
1. **Be Concise**: Skip generic greetings. Provide direct technical answers.
2. **Show Exact Code**: When fixing a bug, provide the exact file name (e.g., `ViewModels/StoryViewModel.swift`) and the exact code block to replace.
3. **Think About Edge Cases**: Before writing network code, always ask yourself: "What if the user loses internet here?", "What if the API times out after 30 seconds?".
4. **Preserve UI**: The current SwiftUI UI and animations are highly polished. Do not break existing view structures or color hex codes when modifying underlying logic.
5. **Print Statements**: Use clear, prefixed print statements for debugging (e.g., `print("[AIService] Timeout on Page 3")`).
