import SwiftUI

class SettingsViewModel: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    /// Debug-only: skip AI illustrations to save tokens. See AppConfig.skipImageGeneration.
    @AppStorage(AppConfig.skipImageGenerationKey) var skipImageGeneration: Bool = true
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("selectedLanguage") var selectedLanguage: String = "English"
    @AppStorage("dailyReminderEnabled") var dailyReminderEnabled: Bool = false
}
