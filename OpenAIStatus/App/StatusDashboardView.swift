import SwiftUI

struct StatusDashboardView: View {
    @EnvironmentObject private var monitor: StatusMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let snapshot = monitor.snapshot {
                    summaryCard(snapshot)

                    if !snapshot.activeIncidents.isEmpty {
                        incidentSection(snapshot.activeIncidents)
                    }

                    componentSection(snapshot)
                } else if monitor.isLoading {
                    loadingCard
                } else {
                    unavailableCard
                }

                footer
            }
            .padding(24)
        }
        .background(background)
        .task {
            monitor.start()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("OpenAI Status")
                    .font(.title2.weight(.bold))
                Text("公式ステータスを自動確認")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SettingsLink {
                Image(systemName: "bell.badge")
            }
            .buttonStyle(.bordered)
            .help("通知設定")

            Button {
                Task { await monitor.refresh() }
            } label: {
                if monitor.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .help("今すぐ更新")
            .disabled(monitor.isLoading)
        }
    }

    private func summaryCard(_ snapshot: OpenAIStatusSnapshot) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor(snapshot).opacity(0.16))
                Circle()
                    .fill(statusColor(snapshot))
                    .frame(width: 18, height: 18)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.isOperational ? "すべてのシステムが正常です" : snapshot.overall.description)
                    .font(.headline)
                Text(snapshot.isOperational
                     ? "現在、OpenAIから障害は報告されていません。"
                     : "影響サービス \(snapshot.affectedComponents.count)件・進行中の障害 \(snapshot.activeIncidents.count)件")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .cardBackground()
    }

    private func incidentSection(_ incidents: [Incident]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("進行中の障害", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(incidents.prefix(3)) { incident in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(incident.name).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(incident.status.statusDisplayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.14), in: Capsule())
                    }
                    if let message = incident.latestMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(14)
                .cardBackground()
            }
        }
    }

    private func componentSection(_ snapshot: OpenAIStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("サービス", systemImage: "square.grid.2x2")
                    .font(.headline)
                Spacer()
                Text("\(snapshot.components.filter(\.isOperational).count)/\(snapshot.components.count) 正常")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(snapshot.components) { component in
                    HStack(spacing: 9) {
                        Circle()
                            .fill(component.isOperational ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(component.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .cardBackground(cornerRadius: 10)
                }
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("公式ステータスを確認しています…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cardBackground()
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ステータスを取得できません", systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text(monitor.errorText ?? "ネットワーク接続を確認して、もう一度お試しください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cardBackground()
    }

    private var footer: some View {
        HStack {
            if let snapshot = monitor.snapshot {
                Text("更新: \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Link(destination: OpenAIStatusClient.statusPageURL) {
                Label("公式ページを開く", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor), Color.teal.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func statusColor(_ snapshot: OpenAIStatusSnapshot) -> Color {
        if snapshot.isOperational { return .green }
        switch snapshot.overall.indicator.lowercased() {
        case "critical", "major": return .red
        default: return .orange
        }
    }

}

private extension View {
    func cardBackground(cornerRadius: CGFloat = 16) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10))
            }
    }
}
