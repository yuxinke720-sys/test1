# StoryMe — MVP Gap Analysis & Action Plan
# StoryMe — MVP 差距分析与行动计划

> Generated after reading every file in the codebase (20+ Swift files, configs, assets).
> Last updated: April 2026

---

## 🗺️ What the App Can Do Right Now (当前状态)

StoryMe is a SwiftUI iOS app that generates personalized AI picture books for children ages 3–6. The user uploads 1–10 photos of their child, the app analyzes the child's appearance via Volcengine Doubao's vision API, then generates a multi-page story with text and AI-illustrated images tailored to that child. The full creation flow works end-to-end: photo upload → appearance analysis → theme/style selection → concurrent text + image generation → page-by-page reader with swipe navigation. Stories are saved locally (UserDefaults) and the app can restore reading sessions across launches. There's also a template library with 7 pre-written story blueprints. The UI is polished — a full design system with custom colors, smooth animations, a calendar view, favorites, and a 5-tab navigation bar. **However**, there is no backend, no authentication, no monetization, no sharing functionality, and the API keys are hardcoded in the app binary.

---

## 🚦 MVP Gap Analysis (MVP 差距分析)

| Feature | Status | Blocking for MVP? | Effort | Notes |
|---------|--------|--------------------|--------|-------|
| **Story text generation** | ✅ Done | — | — | Volcengine Doubao, works well |
| **Story image generation** | ✅ Done | — | — | 2048×2048, concurrent via TaskGroup |
| **Child appearance analysis** | ✅ Done | — | — | Vision API, graceful fallback if fails |
| **Photo upload flow** | ✅ Done | — | — | PhotosPicker, 1–10 photos, tips UI |
| **Story reader (swipe/tap)** | ✅ Done | — | — | Page transitions, overlay controls |
| **Story saving & restore** | ✅ Done | — | — | UserDefaults JSON, session restore |
| **Template library** | ✅ Done | — | — | 7 templates, browse/preview/use |
| **Home dashboard** | ✅ Done | — | — | Calendar, recent books, greeting |
| **My Books library** | ✅ Done | — | — | Grid view, favorites, stats |
| **Design system** | ✅ Done | — | — | Colors, typography, consistent |
| **Backend proxy for API keys** | ❌ Missing | **Yes — critical** | Large (2–4 weeks) | Keys in binary = anyone can extract and drain your budget |
| **Image storage migration** | ❌ Missing | **Yes — critical** | Medium (2–3 days) | Binary images in UserDefaults will crash after 2–3 stories (~5MB limit) |
| **App icon** | ❌ Missing | **Yes** | Small (hours) | Placeholder only in Assets.xcassets |
| **Privacy policy** | ❌ Missing | **Yes** | Small (hours) | Required by App Store; doubly required for COPPA (kids app) |
| **Share/export** | 🔧 Partial | **Yes** | Medium (3–5 days) | UI exists (PDF, Images, Print, Share buttons) but all are non-functional |
| **Authentication** | ❌ Missing | **Yes** (if building backend) | Medium (3–5 days) | Sign in with Apple — needed to associate users with quotas |
| **Crash reporting** | ❌ Missing | **Yes** | Small (hours) | Zero visibility into production crashes |
| **Error retry for images** | ❌ Missing | Recommended | Small (1 day) | Failed images → blank pages, no retry. Users will see broken stories. |
| **Settings screen** | 🔧 Partial | No | Medium (2–3 days) | UI exists but every row is a dead tap |
| **Profile screen** | 🔧 Partial | No | Medium (2–3 days) | Hardcoded "Emma's Mom", "Age 2" — not data-bound |
| **StorySetup character preview** | 🔧 Partial | No | Small (hours) | Shows hardcoded text instead of actual appearance analysis result |
| **"Regenerate description" button** | 🔧 Partial | No | Small (hours) | Button exists in StorySetupView but does nothing |
| **Monetization (IAP/subscription)** | ❌ Missing | No (unless charging) | Large (1–2 weeks) | `isPro: true` on templates but no StoreKit integration |
| **Database (CoreData/SwiftData)** | ❌ Missing | No (post-MVP) | Large (1–2 weeks) | UserDefaults works for <5 stories; need real DB at scale |
| **Localization (i18n)** | ❌ Missing | No | Medium (3–5 days) | All strings hardcoded in English |
| **Push notifications** | ❌ Missing | No | Medium (2–3 days) | "Bedtime story time!" reminders |
| **Unit/UI tests** | ❌ Missing | No | Large (ongoing) | Zero test coverage |
| **iPad support** | ❌ Missing | No | Medium (3–5 days) | Portrait iPhone only |
| **Cloud sync / backup** | ❌ Missing | No | Large (1–2 weeks) | Stories lost on reinstall |
| **Rate limit handling (429)** | ❌ Missing | Recommended | Small (hours) | Volcengine 429 treated as hard failure |

---

## 🔥 Critical Path to MVP (Do These First) (关键路径)

These are ordered by dependency — each step unblocks the next.

### 1. Migrate image storage from UserDefaults to FileManager

**What**: Store generated images as files in the app's `Documents/` directory. Replace `StoryPage.imageData: Data?` with `imageStoragePath: String?`. Load images lazily from disk.

**Why it's blocking**: Your app will **break after 2–3 stories**. Each story is 1–3 MB of image data serialized into UserDefaults JSON. Apple's practical limit is ~5 MB. Once exceeded, `UserDefaults.standard.synchronize()` silently fails and all story data is lost. This is not theoretical — it will happen the first day a real user creates a few stories.

**Concrete first step**: Add a `ImageStorageService` with `save(imageData: Data, storyId: UUID, pageNumber: Int) -> String` that writes to `Documents/stories/{storyId}/page_{n}.jpg` and returns the relative path. Update `StoryPage` to store the path instead of raw bytes.

---

### 2. Add crash reporting (Firebase Crashlytics or Sentry)

**What**: Integrate a crash reporting SDK so you know when and why the app breaks in production.

**Why it's blocking**: You're about to ship an app that calls external APIs, does concurrent image generation, and persists data to disk. Without crash reporting, bugs will be invisible. A user's app crashes → you never know.

**Concrete first step**: `pod 'FirebaseCrashlytics'` or Swift Package Manager → add `FirebaseApp.configure()` in `StoryMeApp.init()`. Takes 30 minutes.

---

### 3. Build the backend proxy (API key protection)

**What**: A server that holds the Volcengine API keys and proxies text/image generation requests from the iOS app. The app calls *your* server; your server calls Volcengine.

**Why it's blocking**: Your Doubao API keys (`5a1fa91d-...` and `c1397e55-...`) are embedded in the compiled app binary. Anyone can extract them with `strings StoryMe.app/StoryMe | grep -i api`. Once extracted, they can generate unlimited stories on your dime. This is not a future risk — it's exploitable today.

**Concrete first step**: Create a `backend/` directory. Set up a minimal Fastify server with one route: `POST /api/generate-story` that accepts `{childName, theme, style, pageCount, childAppearance}`, calls the Doubao text API with the server-side key, and returns the story JSON. Deploy to Railway. Update `AIService.swift` to call your server instead of `ark.cn-beijing.volces.com`.

---

### 4. Add authentication (Sign in with Apple)

**What**: Let users create accounts via Sign in with Apple. Issue JWT tokens from your backend. Require auth on all API calls.

**Why it's blocking**: Without auth, your backend proxy is just as exposed as the raw API keys — anyone can call it. Auth lets you associate requests with users, enforce per-user quotas, and ban abusers.

**Concrete first step**: Add a "Sign in with Apple" button on the home screen (Apple provides the `ASAuthorizationAppleIDButton` SwiftUI view). Send the identity token to `POST /auth/apple` on your backend. Verify against Apple's JWKS. Return access + refresh tokens.

---

### 5. Add rate limiting and usage quotas

**What**: Redis-based rate limiting (per IP and per user) plus a monthly token/story quota system in the database.

**Why it's blocking**: Even with auth, one user can generate 1,000 stories and drain your budget. You need per-user limits (e.g., 10 stories/month free) before you can safely expose the app to real users.

**Concrete first step**: Add a `usage_quotas` table (see `BACKEND_SECURITY_PLAN.md` Section 5). Check quota before every LLM call. Return `429` with `resetsAt` timestamp when exceeded.

---

### 6. Make share/export functional

**What**: Wire up the existing ShareView buttons (PDF, Images, Share) to actually export content.

**Why it's blocking**: This is a children's picture book app — parents will want to share stories with family. The share buttons are prominently displayed but do nothing. This will be reported as a bug immediately.

**Concrete first step**: Implement "Share" first (easiest). Use `UIActivityViewController` to share the story title + first page image. Then implement "Save to Camera Roll" using `UIImageWriteToSavedPhotosAlbum`.

---

### 7. Create app icon and privacy policy

**What**: Design a real app icon (replace the empty placeholder in `Assets.xcassets/AppIcon.appiconset/`). Write and host a privacy policy.

**Why it's blocking**: App Store Review will **reject** the app without both of these. For a kids' app, the privacy policy must explicitly address COPPA — what data you collect from children, how long you store it, and parental consent mechanisms.

**Concrete first step**: For the icon — create a 1024×1024 PNG with the StoryMe brand. For privacy policy — use a generator like iubenda.com, then host it on a simple static page (GitHub Pages works).

---

### 8. Add image generation retry logic

**What**: Retry failed image generation calls with exponential backoff (3 attempts, 1s → 2s → 4s delays).

**Why it's blocking**: Currently, if Volcengine returns a timeout or 5xx error for any page's image, that page is permanently blank. With 6–12 images per story generated concurrently, even a 5% failure rate means ~1 in 3 stories will have a missing illustration. Users will think the app is broken.

**Concrete first step**: Wrap the `callImageAPI()` call in `generateIllustrations()` (AIService.swift line 400) with a retry loop. Add `Task.sleep(nanoseconds:)` between attempts with exponential backoff.

---

## 📦 Nice-to-Have (Post-MVP) (锦上添花)

- **Database migration** (CoreData/SwiftData) — UserDefaults works for <10 stories with the FileManager image fix; migrate to a real DB when you add sync or search
- **Cloud sync** (iCloud or backend) — stories survive reinstall, work across devices
- **Push notifications** — "It's bedtime! Time for a story with {childName}"
- **Localization** — Chinese, Spanish, etc. (big market expansion)
- **iPad layout** — adaptive grid, landscape reading mode
- **Monetization** — StoreKit 2 subscription for premium templates + higher quotas
- **Parental gate** — required for COPPA Kids category; verify parent before settings/purchases
- **Dark mode** — currently forced light mode via `preferredColorScheme(.light)`
- **Offline mode** — cache generated stories for reading without network
- **Story audio** — text-to-speech narration for younger kids who can't read
- **Real settings** — wire up the ProfileView rows (notifications toggle, language, preferences)
- **Apple App Attest** — block modified/emulated clients from calling your backend (see BACKEND_SECURITY_PLAN.md Section 5)
- **Unit tests** — at minimum, test `AIService` response parsing and `StoryViewModel` persistence logic

---

## ⚠️ Risks & Landmines (风险与地雷)

### 🔴 UserDefaults data loss (WILL happen)
Your current storage stores full image binary data (`StoryPage.imageData: Data?`) in UserDefaults as JSON. At ~500KB per page × 6 pages = ~3MB per story, you'll hit the ~5MB UserDefaults limit after 1–2 stories. When this happens, **all stories are silently lost** — `JSONDecoder` fails, `savedStories` resets to empty. The user loses everything with no error message. **Fix this before any user testing.**

### 🔴 API key extraction (exploitable NOW)
`Secrets.xcconfig` contains plaintext API keys. Even though it appears to be in `.gitignore`, the keys are compiled into `Info.plist` and embedded in the binary. Anyone with `strings` or a MITM proxy (Charles/Proxyman) can extract them. If StoryMe gets any visibility, someone will find and abuse these keys within days. The binary also contains the full API endpoint URL (`ark.cn-beijing.volces.com`) making it trivial to locate.

### 🟠 COPPA compliance (App Store rejection risk)
StoryMe targets ages 3–6. Apple's Kids category requires:
1. A privacy policy explicitly addressing children's data
2. No third-party analytics/advertising SDKs that collect data
3. Parental gates for external links, purchases, or settings
4. Compliance with COPPA (US) and GDPR-K (EU)

Your app sends **photos of children** to Volcengine's vision API and receives **appearance descriptions** (hair color, skin tone, face shape). This is biometric-adjacent data about minors. Without a clear privacy policy explaining this, and without Volcengine's own COPPA compliance documentation, App Store Review may reject the app. Worse, you could face legal liability.

### 🟠 Photo privacy messaging is misleading
`PhotoUploadView` line 179 says: *"Photos deleted from our servers after generation."* But photos are never uploaded to a server — they're sent directly to Volcengine's API as base64. This statement is technically false in the current architecture (there is no "our servers") and potentially misleading once you do build a backend. Rewrite this to accurately describe what happens.

### 🟡 Volcengine API cost exposure
Image generation at 2048×2048 is the most expensive operation. With no rate limiting or quotas, a single user can generate unlimited stories. At current pricing, 100 stories × 6 images each = 600 image generations. If this costs ¥0.04/image, that's ¥24 — but at scale or with abuse, costs can spike quickly with zero circuit breaker.

### 🟡 No graceful degradation for API outages
If Volcengine is down or returns errors, the app shows a generic error message and the user is stuck. There's no offline fallback for previously generated stories (they work) but also no way to tell the user "try again later" vs "something is wrong with your input."

### 🟡 AITestView accessible in production
The debug screen (`AITestView`) is accessible via the tab bar ("AI Test" tab in HomeView). This exposes raw API calls to end users and should be removed or hidden behind a developer flag before shipping.

---

## 📅 Rough Timeline Estimate (时间估算)

Assuming one focused developer working full-time:

| Phase | What | Duration | Running Total |
|-------|------|----------|---------------|
| **Week 1** | Image storage migration + crash reporting + image retry logic | 3–4 days | Week 1 |
| **Week 1–2** | App icon + privacy policy + fix misleading copy + remove AITestView from tab bar | 1–2 days | Week 1–2 |
| **Week 2–4** | Backend proxy (Fastify + deploy) + migrate AIService to call backend | 1.5–2 weeks | Week 2–4 |
| **Week 4–5** | Sign in with Apple (iOS + backend) + rate limiting + quotas | 1–1.5 weeks | Week 4–5 |
| **Week 5–6** | Share/export (UIActivityViewController + Save to Camera Roll) + functional settings | 3–5 days | Week 5–6 |
| **Week 6** | Testing, polish, App Store submission prep | 3–5 days | Week 6 |

**Total: ~6 weeks to a shippable MVP.**

This assumes the backend is built from scratch using the blueprint in `BACKEND_SECURITY_PLAN.md`. If you use a BaaS (Backend-as-a-Service) like Supabase or Firebase, weeks 2–5 could compress to 2–3 weeks, reducing total to ~4 weeks.

**What "shippable" means here**: App Store-submittable with API keys protected, basic auth, usage quotas, working share, crash reporting, and COPPA-compliant privacy policy. NOT including: monetization, cloud sync, localization, iPad, push notifications, or tests beyond manual QA.
