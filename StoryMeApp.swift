import SwiftUI
import FirebaseCore // 导入 Firebase 核心库
import FirebaseAuth
import FirebaseFunctions

// MARK: - App Delegate
// Firebase 的初始化必须通过 AppDelegate 在应用启动时完成
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 核心启动指令：连接 Firebase 云端服务
        FirebaseApp.configure()

        #if DEBUG
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        Functions.functions(region: "asia-northeast1")
            .useEmulator(withHost: "127.0.0.1", port: 5001)
        print("[Firebase] Emulators configured — Auth:9099, Functions:5001")
        #endif

        return true
    }
}

@main
struct StoryMeApp: App {
    // 将 AppDelegate 注入到 SwiftUI 的生命周期中
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            // 这里进入你的主界面，并锁定为亮色模式以匹配你的设计稿
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Design System Colors
// 预设的 StoryMe 专属调色板，方便在全项目直接调用
extension Color {
    // 主色调：阳光黄 (Sunny Yellow)
    static let smYellow50  = Color(hex: "FFFEF5")
    static let smYellow100 = Color(hex: "FFFBD4")
    static let smYellow200 = Color(hex: "FFF5A0")
    static let smYellow300 = Color(hex: "FFE94A")
    static let smYellow400 = Color(hex: "FFD93D") // 主色
    static let smYellow500 = Color(hex: "F5C800")
    static let smYellow600 = Color(hex: "C89F00")

    // 点缀色：珊瑚色 (Soft Coral)
    static let smCoral100  = Color(hex: "FFF0EC")
    static let smCoral300  = Color(hex: "FFBFA8")
    static let smCoral400  = Color(hex: "FF8C6B") // 点缀
    static let smCoral500  = Color(hex: "E86D4A")

    // 辅助色
    static let smGreen400  = Color(hex: "6BCB77") // 成功
    static let smBlue400   = Color(hex: "4D96FF")  // 信息
    static let smRed400    = Color(hex: "FF5252")  // 错误

    // 中性色
    static let smNeutral50  = Color(hex: "FAF8F5")
    static let smNeutral100 = Color(hex: "F5F2EE")
    static let smNeutral500 = Color(hex: "7A756E")
    static let smNeutral900 = Color(hex: "1E1C1A")

    // 语义化别名
    static let smBackground    = Color(hex: "F7F3ED")
    static let smTextPrimary   = Color(hex: "1E1C1A")
    static let smTextSecondary = Color(hex: "7A756E")

    // 十六进制颜色转换工具
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
