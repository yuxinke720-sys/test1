import Foundation

struct AppConfig {
    /// Set to `true` to skip AI image generation during development (saves API tokens).
    /// Remember to set back to `false` before release.
    static let skipImageGeneration = true
}
