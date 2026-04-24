import Foundation

struct AppConfig {
    /// 开发者测试开关：设置为 true 时，将跳过真实 AI 图片生成以节省 Token
    /// 想要恢复生成图片时，将其改为 false 即可
    static let skipImageGeneration = true
}
