import Foundation

struct AppConfig {
    /// UserDefaults key for the developer "skip illustrations" toggle (Profile → DEVELOPER, Debug builds only).
    static let skipImageGenerationKey = "devSkipImageGeneration"

    /// 开发者开关：为 true 时跳过 AI 插图生成，只生成文字（节省 Token）。
    /// - Debug：由个人页 DEVELOPER 区的开关控制，默认开启（跳过）。
    /// - Release：永远为 false，用户一定会得到插图。
    static var skipImageGeneration: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: skipImageGenerationKey) as? Bool ?? true
        #else
        return false
        #endif
    }
}
