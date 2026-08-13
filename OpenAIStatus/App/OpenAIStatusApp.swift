import SwiftUI

@main
struct OpenAIStatusApp: App {
    @StateObject private var notificationSettings: NotificationSettingsStore
    @StateObject private var notificationManager: StatusNotificationManager
    @StateObject private var monitor: StatusMonitor

    init() {
        let settings = NotificationSettingsStore()
        let notifications = StatusNotificationManager(settingsStore: settings)
        _notificationSettings = StateObject(wrappedValue: settings)
        _notificationManager = StateObject(wrappedValue: notifications)
        _monitor = StateObject(wrappedValue: StatusMonitor(notificationManager: notifications))
    }

    var body: some Scene {
        WindowGroup("OpenAI Status") {
            StatusDashboardView()
                .frame(minWidth: 520, minHeight: 560)
                .environmentObject(monitor)
                .environmentObject(notificationSettings)
                .environmentObject(notificationManager)
        }
        .defaultSize(width: 620, height: 680)

        Settings {
            NotificationSettingsView()
                .environmentObject(notificationSettings)
                .environmentObject(notificationManager)
        }
    }
}
