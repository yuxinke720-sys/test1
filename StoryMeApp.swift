import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// MARK: - App Delegate
// Firebase must be configured at launch, before any service is touched.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        #if DEBUG
        // Point every service at the local emulators so debug runs never write to production.
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        Functions.functions(region: "asia-northeast1")
            .useEmulator(withHost: "127.0.0.1", port: 5001)

        let db = Firestore.firestore()
        db.useEmulator(withHost: "127.0.0.1", port: 8080)
        let settings = db.settings
        // In-memory cache only, so emulator data never lands in the on-disk production cache.
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings

        print("[Firebase] Emulators configured — Auth:9099, Functions:5001, Firestore:8080")
        #endif

        return true
    }
}

@main
struct StoryMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Design System Colors
// Matches the HiFi prototype token palette (yellow-primary, coral-accent)

extension Color {
    // Primary: Sunny Yellow
    static let smYellow50  = Color(hex: "FFFEF5")
    static let smYellow100 = Color(hex: "FFFBD4")
    static let smYellow200 = Color(hex: "FFF5A0")
    static let smYellow300 = Color(hex: "FFE94A")
    static let smYellow400 = Color(hex: "FFD93D") // PRIMARY
    static let smYellow500 = Color(hex: "F5C800")
    static let smYellow600 = Color(hex: "C89F00")

    // Accent: Soft Coral
    static let smCoral100  = Color(hex: "FFF0EC")
    static let smCoral300  = Color(hex: "FFBFA8")
    static let smCoral400  = Color(hex: "FF8C6B") // ACCENT
    static let smCoral500  = Color(hex: "E86D4A")

    // Success Green
    static let smGreen100  = Color(hex: "E8F8EE")
    static let smGreen400  = Color(hex: "6BCB77")
    static let smGreen600  = Color(hex: "2A8A40")

    // Info Blue
    static let smBlue100   = Color(hex: "EBF3FF")
    static let smBlue400   = Color(hex: "4D96FF")

    // Error Red
    static let smRed100    = Color(hex: "FFECEC")
    static let smRed400    = Color(hex: "FF5252")

    // Neutrals
    static let smNeutral50  = Color(hex: "FAF8F5")
    static let smNeutral100 = Color(hex: "F5F2EE")
    static let smNeutral200 = Color(hex: "E0DBD4")
    static let smNeutral300 = Color(hex: "B8B3AC")
    static let smNeutral500 = Color(hex: "7A756E")
    static let smNeutral700 = Color(hex: "3D3A36")
    static let smNeutral900 = Color(hex: "1E1C1A")

    // Semantic aliases
    static let smBackground    = Color(hex: "F7F3ED")
    static let smTextPrimary   = Color(hex: "1E1C1A")
    static let smTextSecondary = Color(hex: "7A756E")

    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
