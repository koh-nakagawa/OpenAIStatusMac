import Foundation
import UserNotifications

struct KnownStatusComponent: Codable, Hashable, Identifiable {
    let id: String
    let name: String
}

@MainActor
final class NotificationSettingsStore: ObservableObject {
    private enum Key {
        static let enabled = "notifications.enabled"
        static let newIncidents = "notifications.newIncidents"
        static let incidentUpdates = "notifications.incidentUpdates"
        static let componentOutages = "notifications.componentOutages"
        static let recoveries = "notifications.recoveries"
        static let fetchFailures = "notifications.fetchFailures"
        static let excludedComponents = "notifications.excludedComponents"
        static let knownComponents = "notifications.knownComponents"
    }

    private let defaults: UserDefaults

    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Key.enabled) } }
    @Published var notifyNewIncidents: Bool { didSet { defaults.set(notifyNewIncidents, forKey: Key.newIncidents) } }
    @Published var notifyIncidentUpdates: Bool { didSet { defaults.set(notifyIncidentUpdates, forKey: Key.incidentUpdates) } }
    @Published var notifyComponentOutages: Bool { didSet { defaults.set(notifyComponentOutages, forKey: Key.componentOutages) } }
    @Published var notifyRecoveries: Bool { didSet { defaults.set(notifyRecoveries, forKey: Key.recoveries) } }
    @Published var notifyFetchFailures: Bool { didSet { defaults.set(notifyFetchFailures, forKey: Key.fetchFailures) } }
    @Published private(set) var excludedComponentIDs: Set<String>
    @Published private(set) var knownComponents: [KnownStatusComponent]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.newIncidents: true,
            Key.incidentUpdates: false,
            Key.componentOutages: true,
            Key.recoveries: true,
            Key.fetchFailures: false
        ])

        notificationsEnabled = defaults.bool(forKey: Key.enabled)
        notifyNewIncidents = defaults.bool(forKey: Key.newIncidents)
        notifyIncidentUpdates = defaults.bool(forKey: Key.incidentUpdates)
        notifyComponentOutages = defaults.bool(forKey: Key.componentOutages)
        notifyRecoveries = defaults.bool(forKey: Key.recoveries)
        notifyFetchFailures = defaults.bool(forKey: Key.fetchFailures)
        excludedComponentIDs = Set(defaults.stringArray(forKey: Key.excludedComponents) ?? [])

        if let data = defaults.data(forKey: Key.knownComponents),
           let components = try? JSONDecoder().decode([KnownStatusComponent].self, from: data) {
            knownComponents = components
        } else {
            knownComponents = []
        }
    }

    var allComponentsEnabled: Bool {
        knownComponents.allSatisfy { !excludedComponentIDs.contains($0.id) }
    }

    func isComponentEnabled(_ id: String) -> Bool {
        !excludedComponentIDs.contains(id)
    }

    func setComponent(_ id: String, enabled: Bool) {
        if enabled {
            excludedComponentIDs.remove(id)
        } else {
            excludedComponentIDs.insert(id)
        }
        saveExcludedComponents()
    }

    func setAllComponents(enabled: Bool) {
        excludedComponentIDs = enabled ? [] : Set(knownComponents.map(\.id))
        saveExcludedComponents()
    }

    func updateKnownComponents(_ components: [ComponentStatus]) {
        let updated = components
            .map { KnownStatusComponent(id: $0.id, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard updated != knownComponents else { return }
        knownComponents = updated
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: Key.knownComponents)
        }
    }

    func resetToDefaults() {
        notificationsEnabled = true
        notifyNewIncidents = true
        notifyIncidentUpdates = false
        notifyComponentOutages = true
        notifyRecoveries = true
        notifyFetchFailures = false
        excludedComponentIDs = []
        saveExcludedComponents()
    }

    var selection: StatusNotificationSelection {
        let enabledIDs = Set(knownComponents.map(\.id)).subtracting(excludedComponentIDs)
        return StatusNotificationSelection(
            notifyNewIncidents: notifyNewIncidents,
            notifyIncidentUpdates: notifyIncidentUpdates,
            notifyComponentOutages: notifyComponentOutages,
            notifyRecoveries: notifyRecoveries,
            monitoredComponentIDs: knownComponents.isEmpty ? nil : enabledIDs
        )
    }

    private func saveExcludedComponents() {
        defaults.set(excludedComponentIDs.sorted(), forKey: Key.excludedComponents)
    }
}

@MainActor
final class StatusNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private enum Key {
        static let baseline = "notifications.statusBaseline"
        static let fetchFailed = "notifications.fetchFailed"
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    let settingsStore: NotificationSettingsStore
    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults

    init(settingsStore: NotificationSettingsStore, defaults: UserDefaults = .standard) {
        self.settingsStore = settingsStore
        self.defaults = defaults
        super.init()
        center.delegate = self
    }

    var authorizationDescription: String {
        switch authorizationStatus {
        case .authorized: "許可済み"
        case .denied: "許可されていません"
        case .provisional: "仮許可"
        case .notDetermined: "未確認"
        @unknown default: "不明"
        }
    }

    var canDeliverNotifications: Bool {
        authorizationStatus == .authorized
            || authorizationStatus == .provisional
    }

    func prepare() async {
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined, settingsStore.notificationsEnabled {
            await requestPermission()
        }
    }

    func requestPermission() async {
        _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
        await refreshAuthorizationStatus()
    }

    func process(snapshot: OpenAIStatusSnapshot) {
        settingsStore.updateKnownComponents(snapshot.components)
        defaults.set(false, forKey: Key.fetchFailed)

        let previous = loadBaseline()
        let current = StatusNotificationBaseline(snapshot: snapshot)
        saveBaseline(current)

        guard settingsStore.notificationsEnabled, canDeliverNotifications else { return }
        let changes = StatusNotificationPolicy.changes(
            from: previous,
            to: snapshot,
            selection: settingsStore.selection
        )
        guard !changes.isEmpty else { return }
        deliver(changes: changes)
    }

    func processFetchFailure(_ error: Error) {
        let wasAlreadyFailing = defaults.bool(forKey: Key.fetchFailed)
        defaults.set(true, forKey: Key.fetchFailed)
        guard settingsStore.notificationsEnabled,
              settingsStore.notifyFetchFailures,
              canDeliverNotifications,
              !wasAlreadyFailing else { return }

        deliver(
            title: "OpenAIステータスを取得できません",
            body: error.localizedDescription,
            identifierPrefix: "fetch-failure"
        )
    }

    func sendTestNotification() {
        guard canDeliverNotifications else { return }
        deliver(
            title: "OpenAI Status テスト通知",
            body: "通知は正常に設定されています。",
            identifierPrefix: "test"
        )
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func loadBaseline() -> StatusNotificationBaseline? {
        guard let data = defaults.data(forKey: Key.baseline) else { return nil }
        return try? JSONDecoder().decode(StatusNotificationBaseline.self, from: data)
    }

    private func saveBaseline(_ baseline: StatusNotificationBaseline) {
        if let data = try? JSONEncoder().encode(baseline) {
            defaults.set(data, forKey: Key.baseline)
        }
    }

    private func deliver(changes: StatusNotificationChanges) {
        var details: [String] = []
        if !changes.newIncidentNames.isEmpty {
            details.append("新規障害: \(summarize(changes.newIncidentNames))")
        }
        if !changes.newlyAffectedComponentNames.isEmpty {
            details.append("影響サービス: \(summarize(changes.newlyAffectedComponentNames))")
        }
        if !changes.updatedIncidentNames.isEmpty {
            details.append("更新: \(summarize(changes.updatedIncidentNames))")
        }
        if !changes.recoveredComponentNames.isEmpty {
            details.append("復旧: \(summarize(changes.recoveredComponentNames))")
        }
        if changes.resolvedIncidentCount > 0 {
            details.append("解決済み障害: \(changes.resolvedIncidentCount)件")
        }

        let hasProblem = !changes.newIncidentNames.isEmpty
            || !changes.newlyAffectedComponentNames.isEmpty
            || !changes.updatedIncidentNames.isEmpty
        let title = hasProblem ? "OpenAIでステータス変化" : "OpenAIサービスが復旧"
        deliver(title: title, body: details.joined(separator: "\n"), identifierPrefix: "status-change")
    }

    private func summarize(_ names: [String]) -> String {
        let visible = names.prefix(3).joined(separator: "、")
        let remainder = names.count - min(names.count, 3)
        return remainder > 0 ? "\(visible) ほか\(remainder)件" : visible
    }

    private func deliver(title: String, body: String, identifierPrefix: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "openai-status"

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
final class StatusMonitor: ObservableObject {
    @Published private(set) var snapshot: OpenAIStatusSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorText: String?

    private let notificationManager: StatusNotificationManager
    private var monitoringTask: Task<Void, Never>?

    init(notificationManager: StatusNotificationManager) {
        self.notificationManager = notificationManager
    }

    func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            await notificationManager.prepare()
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await refresh(silent: true)
            }
        }
    }

    func refresh(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }

        do {
            let latest = try await OpenAIStatusClient.fetchSnapshot()
            snapshot = latest
            errorText = nil
            notificationManager.process(snapshot: latest)
        } catch {
            errorText = error.localizedDescription
            notificationManager.processFetchFailure(error)
        }
    }

    deinit {
        monitoringTask?.cancel()
    }
}
