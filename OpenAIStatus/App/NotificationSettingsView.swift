import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var settings: NotificationSettingsStore
    @EnvironmentObject private var notificationManager: StatusNotificationManager

    var body: some View {
        Form {
            Section("通知") {
                Toggle("ステータス通知を有効にする", isOn: $settings.notificationsEnabled)

                LabeledContent("macOSの通知権限", value: notificationManager.authorizationDescription)

                HStack {
                    if !notificationManager.canDeliverNotifications {
                        Button("通知を許可") {
                            Task { await notificationManager.requestPermission() }
                        }
                    }
                    Button("テスト通知を送る") {
                        notificationManager.sendTestNotification()
                    }
                    .disabled(!notificationManager.canDeliverNotifications)
                }

                if notificationManager.authorizationStatus == .denied {
                    Text("システム設定 → 通知 → OpenAI Status で通知を許可してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("通知する変化") {
                Toggle("新しい障害", isOn: $settings.notifyNewIncidents)
                Toggle("サービスの性能低下・停止", isOn: $settings.notifyComponentOutages)
                Toggle("障害情報の更新", isOn: $settings.notifyIncidentUpdates)
                Toggle("障害・サービスの復旧", isOn: $settings.notifyRecoveries)
                Toggle("ステータス取得失敗", isOn: $settings.notifyFetchFailures)
            }
            .disabled(!settings.notificationsEnabled)

            Section("通知対象サービス") {
                Toggle(
                    "すべてのサービス",
                    isOn: Binding(
                        get: { settings.allComponentsEnabled },
                        set: { settings.setAllComponents(enabled: $0) }
                    )
                )

                if settings.knownComponents.isEmpty {
                    Text("ステータスを取得するとサービス一覧が表示されます。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.knownComponents) { component in
                        Toggle(
                            component.name,
                            isOn: Binding(
                                get: { settings.isComponentEnabled(component.id) },
                                set: { settings.setComponent(component.id, enabled: $0) }
                            )
                        )
                    }
                }
            }
            .disabled(!settings.notificationsEnabled || !settings.notifyComponentOutages)

            Section {
                Button("デフォルト設定に戻す") {
                    settings.resetToDefaults()
                }
            } footer: {
                Text("同じ状態は繰り返し通知せず、前回確認時から変化した場合だけ通知します。監視はOpenAI Statusアプリの起動中に行われます。")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 650)
        .padding(.top, 8)
        .task {
            await notificationManager.prepare()
        }
    }
}
