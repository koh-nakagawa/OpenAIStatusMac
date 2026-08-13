import Foundation
import OpenAIStatusCore

@main
struct StatusVerifier {
    static func main() async throws {
        let summaryJSON = """
        {
          "page":{"id":"p","name":"OpenAI","url":"https://status.openai.com/","updated_at":"2026-08-11T00:00:00Z"},
          "status":{"description":"Minor Service Outage","indicator":"minor"},
          "components":[
            {"id":"a","name":"API","status":"partial_outage","updated_at":"2026-08-11T00:00:00Z"},
            {"id":"b","name":"ChatGPT","status":"operational","updated_at":"2026-08-11T00:00:00Z"}
          ]
        }
        """
        let incidentsJSON = """
        {
          "page":{"id":"p","name":"OpenAI","url":"https://status.openai.com/","updated_at":"2026-08-11T00:00:00Z"},
          "incidents":[
            {"id":"i1","name":"API errors","status":"monitoring","created_at":"2026-08-11T00:00:00Z","updated_at":"2026-08-11T00:10:00Z","resolved_at":null,"impact":"minor","incident_updates":[]},
            {"id":"i2","name":"Old issue","status":"resolved","created_at":"2026-08-10T00:00:00Z","updated_at":"2026-08-10T00:10:00Z","resolved_at":"2026-08-10T00:10:00Z","impact":"minor","incident_updates":[]}
          ]
        }
        """

        let decoder = JSONDecoder()
        let summary = try decoder.decode(StatusSummaryResponse.self, from: Data(summaryJSON.utf8))
        let incidents = try decoder.decode(IncidentsResponse.self, from: Data(incidentsJSON.utf8))
        let fixture = OpenAIStatusSnapshot(summary: summary, incidents: incidents)

        guard fixture.affectedComponents.map(\.name) == ["API"] else {
            throw VerificationError.fixtureComponentFilter
        }
        guard fixture.activeIncidents.map(\.name) == ["API errors"] else {
            throw VerificationError.fixtureIncidentFilter
        }

        let live = try await OpenAIStatusClient.fetchSnapshot()
        guard !live.page.name.isEmpty, !live.components.isEmpty else {
            throw VerificationError.emptyLiveResponse
        }

        print("PASS fixture filtering")
        print("PASS live OpenAI status response: \(live.overall.description)")
        print("PASS decoded \(live.components.count) components and \(live.activeIncidents.count) active incidents")
    }
}

enum VerificationError: Error {
    case fixtureComponentFilter
    case fixtureIncidentFilter
    case emptyLiveResponse
}
