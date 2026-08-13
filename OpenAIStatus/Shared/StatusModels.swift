import Foundation

public struct StatusPage: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let url: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, url
        case updatedAt = "updated_at"
    }
}

public struct OverallStatus: Codable, Sendable, Equatable {
    public let description: String
    public let indicator: String
}

public struct ComponentStatus: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let status: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case updatedAt = "updated_at"
    }

    public var isOperational: Bool {
        status.lowercased() == "operational"
    }
}

public struct IncidentUpdate: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let body: String
    public let status: String
    public let displayAt: String

    enum CodingKeys: String, CodingKey {
        case id, body, status
        case displayAt = "display_at"
    }
}

public struct Incident: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let status: String
    public let createdAt: String
    public let updatedAt: String
    public let resolvedAt: String?
    public let impact: String
    public let incidentUpdates: [IncidentUpdate]

    enum CodingKeys: String, CodingKey {
        case id, name, status, impact
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case resolvedAt = "resolved_at"
        case incidentUpdates = "incident_updates"
    }

    public var isActive: Bool {
        status.lowercased() != "resolved" && resolvedAt == nil
    }

    public var latestMessage: String? {
        incidentUpdates.max(by: { $0.displayAt < $1.displayAt })?.body
    }
}

public struct StatusSummaryResponse: Codable, Sendable, Equatable {
    public let page: StatusPage
    public let status: OverallStatus
    public let components: [ComponentStatus]
}

public struct IncidentsResponse: Codable, Sendable, Equatable {
    public let page: StatusPage
    public let incidents: [Incident]
}

public struct OpenAIStatusSnapshot: Sendable, Equatable {
    public let page: StatusPage
    public let overall: OverallStatus
    public let components: [ComponentStatus]
    public let affectedComponents: [ComponentStatus]
    public let activeIncidents: [Incident]
    public let fetchedAt: Date

    public init(
        summary: StatusSummaryResponse,
        incidents: IncidentsResponse,
        fetchedAt: Date = Date()
    ) {
        page = summary.page
        overall = summary.status
        components = summary.components.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        affectedComponents = summary.components
            .filter { !$0.isOperational }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        activeIncidents = incidents.incidents
            .filter(\.isActive)
            .sorted { $0.createdAt > $1.createdAt }
        self.fetchedAt = fetchedAt
    }

    public var isOperational: Bool {
        overall.indicator.lowercased() == "none"
            && affectedComponents.isEmpty
            && activeIncidents.isEmpty
    }
}

public extension String {
    var statusDisplayName: String {
        switch lowercased().replacingOccurrences(of: "_", with: " ") {
        case "operational": "正常"
        case "degraded performance": "性能低下"
        case "partial outage": "一部障害"
        case "major outage": "重大障害"
        case "under maintenance": "メンテナンス中"
        case "investigating": "調査中"
        case "identified": "原因特定"
        case "monitoring": "監視中"
        case "resolved": "解決済み"
        default: replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
