import AppIntents
import SwiftUI
import WidgetKit

struct OpenAIStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: OpenAIStatusSnapshot?
    let errorMessage: String?
}

struct OpenAIStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenAIStatusEntry {
        OpenAIStatusEntry(date: Date(), snapshot: nil, errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OpenAIStatusEntry) -> Void) {
        if context.isPreview {
            completion(OpenAIStatusEntry(date: Date(), snapshot: nil, errorMessage: nil))
            return
        }
        load(completion: completion)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenAIStatusEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private func load(completion: @escaping (OpenAIStatusEntry) -> Void) {
        Task { completion(await makeEntry()) }
    }

    private func makeEntry() async -> OpenAIStatusEntry {
        do {
            return OpenAIStatusEntry(date: Date(), snapshot: try await OpenAIStatusClient.fetchSnapshot(), errorMessage: nil)
        } catch {
            return OpenAIStatusEntry(date: Date(), snapshot: nil, errorMessage: error.localizedDescription)
        }
    }
}

struct OpenAIStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OpenAIStatusEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else if entry.errorMessage != nil {
                unavailable
            } else {
                placeholder
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [.black.opacity(0.94), .teal.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(OpenAIStatusClient.statusPageURL)
    }

    private func content(_ snapshot: OpenAIStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                Text("OpenAI")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(statusColor(snapshot))
                    .frame(width: 10, height: 10)
                    .shadow(color: statusColor(snapshot).opacity(0.7), radius: 4)
            }

            Spacer(minLength: 2)

            Text(snapshot.isOperational ? "正常稼働中" : "障害情報あり")
                .font(family == .systemSmall ? .title3.bold() : .title2.bold())
                .minimumScaleFactor(0.75)

            if family == .systemSmall {
                Text(snapshot.isOperational
                     ? "全 \(snapshot.components.count) サービス"
                     : "影響 \(snapshot.affectedComponents.count)・障害 \(snapshot.activeIncidents.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                detailRows(snapshot)
            }

            Spacer(minLength: 0)

            Text("\(entry.date.formatted(date: .omitted, time: .shortened)) 更新")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func detailRows(_ snapshot: OpenAIStatusSnapshot) -> some View {
        if let incident = snapshot.activeIncidents.first {
            Label(incident.name, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .lineLimit(2)
        } else if !snapshot.affectedComponents.isEmpty {
            ForEach(snapshot.affectedComponents.prefix(3)) { component in
                Label(component.name, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .lineLimit(1)
            }
        } else {
            Text("API・ChatGPT・Codexなど、\n公式掲載サービスを監視しています。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("OpenAI", systemImage: "waveform.path.ecg")
                .font(.headline)
            Spacer()
            Text("確認中…").font(.title3.bold())
            ProgressView().controlSize(.small)
        }
        .foregroundStyle(.white)
        .redacted(reason: .placeholder)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("OpenAI", systemImage: "waveform.path.ecg")
                .font(.headline)
            Spacer()
            Label("取得できません", systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text("クリックして公式ページを開く")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
    }

    private func statusColor(_ snapshot: OpenAIStatusSnapshot) -> Color {
        if snapshot.isOperational { return .green }
        return snapshot.overall.indicator.lowercased() == "critical" ? .red : .orange
    }
}

struct OpenAIStatusWidget: Widget {
    let kind = "OpenAIStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenAIStatusProvider()) { entry in
            OpenAIStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("OpenAI Status")
        .description("OpenAI公式ステータスの稼働状況と障害情報を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(macOS 26.0, *)
private struct OpenAIStatusControlValue: Sendable {
    let title: String
    let symbolName: String
}

@available(macOS 26.0, *)
private struct OpenAIStatusControlProvider: ControlValueProvider {
    var previewValue: OpenAIStatusControlValue {
        OpenAIStatusControlValue(title: "OpenAI 正常", symbolName: "checkmark.circle.fill")
    }

    func currentValue() async throws -> OpenAIStatusControlValue {
        do {
            let snapshot = try await OpenAIStatusClient.fetchSnapshot()
            if snapshot.isOperational {
                return OpenAIStatusControlValue(
                    title: "OpenAI 正常",
                    symbolName: "checkmark.circle.fill"
                )
            }

            return OpenAIStatusControlValue(
                title: "OpenAI 障害情報あり",
                symbolName: "exclamationmark.triangle.fill"
            )
        } catch {
            return OpenAIStatusControlValue(
                title: "OpenAI 取得不可",
                symbolName: "wifi.exclamationmark"
            )
        }
    }
}

@available(macOS 26.0, *)
private struct OpenAIStatusControlIntent: AppIntent {
    static let title: LocalizedStringResource = "OpenAI Statusを開く"
    static let description = IntentDescription("OpenAI Statusアプリを開きます。")
    static let supportedModes: IntentModes = .foreground(.immediate)

    func perform() async throws -> some IntentResult {
        .result()
    }
}

@available(macOS 26.0, *)
private struct OpenAIStatusControl: ControlWidget {
    let kind = "OpenAIStatusControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind, provider: OpenAIStatusControlProvider()) { value in
            ControlWidgetButton(action: OpenAIStatusControlIntent()) {
                Label(value.title, systemImage: value.symbolName)
            }
        }
        .displayName("OpenAI Status")
        .description("OpenAIの稼働状況を確認し、アプリを開きます。")
    }
}

@main
struct OpenAIStatusWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        OpenAIStatusWidget()

        if #available(macOS 26.0, *) {
            OpenAIStatusControl()
        }
    }
}
