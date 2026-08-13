import Foundation
import XCTest
@testable import OpenAIStatusCore

final class StatusCoreTests: XCTestCase {
func testSnapshotFiltersResolvedIncidentsAndOperationalComponents() throws {
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

    let summary = try JSONDecoder().decode(StatusSummaryResponse.self, from: Data(summaryJSON.utf8))
    let incidents = try JSONDecoder().decode(IncidentsResponse.self, from: Data(incidentsJSON.utf8))
    let snapshot = OpenAIStatusSnapshot(summary: summary, incidents: incidents)

    XCTAssertEqual(snapshot.affectedComponents.map(\.name), ["API"])
    XCTAssertEqual(snapshot.activeIncidents.map(\.name), ["API errors"])
    XCTAssertFalse(snapshot.isOperational)
}

func testOperationalSnapshotIsHealthy() throws {
    let summary = StatusSummaryResponse(
        page: StatusPage(id: "p", name: "OpenAI", url: "https://status.openai.com/", updatedAt: "now"),
        status: OverallStatus(description: "All Systems Operational", indicator: "none"),
        components: []
    )
    let incidents = IncidentsResponse(page: summary.page, incidents: [])
    XCTAssertTrue(OpenAIStatusSnapshot(summary: summary, incidents: incidents).isOperational)
}

func testNotificationPolicyEmitsOnlyStateChanges() throws {
    let healthy = makeSnapshot(componentStatus: "operational", incidents: [])
    let incident = Incident(
        id: "i1",
        name: "API errors",
        status: "investigating",
        createdAt: "2026-08-13T00:00:00Z",
        updatedAt: "2026-08-13T00:05:00Z",
        resolvedAt: nil,
        impact: "minor",
        incidentUpdates: [
            IncidentUpdate(id: "u1", body: "Investigating", status: "investigating", displayAt: "2026-08-13T00:05:00Z")
        ]
    )
    let degraded = makeSnapshot(componentStatus: "partial_outage", incidents: [incident])
    let selection = StatusNotificationSelection(
        notifyNewIncidents: true,
        notifyIncidentUpdates: true,
        notifyComponentOutages: true,
        notifyRecoveries: true
    )

    let firstChange = StatusNotificationPolicy.changes(
        from: StatusNotificationBaseline(snapshot: healthy),
        to: degraded,
        selection: selection
    )
    XCTAssertEqual(firstChange.newIncidentNames, ["API errors"])
    XCTAssertEqual(firstChange.newlyAffectedComponentNames, ["API"])

    let unchanged = StatusNotificationPolicy.changes(
        from: StatusNotificationBaseline(snapshot: degraded),
        to: degraded,
        selection: selection
    )
    XCTAssertTrue(unchanged.isEmpty)

    let recovered = StatusNotificationPolicy.changes(
        from: StatusNotificationBaseline(snapshot: degraded),
        to: healthy,
        selection: selection
    )
    XCTAssertEqual(recovered.recoveredComponentNames, ["API"])
    XCTAssertEqual(recovered.resolvedIncidentCount, 1)
}

func testNotificationPolicyHonorsSelectedServices() throws {
    let healthy = makeSnapshot(componentStatus: "operational", incidents: [])
    let degraded = makeSnapshot(componentStatus: "major_outage", incidents: [])
    let selection = StatusNotificationSelection(
        notifyNewIncidents: true,
        notifyIncidentUpdates: false,
        notifyComponentOutages: true,
        notifyRecoveries: true,
        monitoredComponentIDs: ["another-component"]
    )

    let changes = StatusNotificationPolicy.changes(
        from: StatusNotificationBaseline(snapshot: healthy),
        to: degraded,
        selection: selection
    )
    XCTAssertTrue(changes.newlyAffectedComponentNames.isEmpty)
    XCTAssertTrue(changes.isEmpty)
}

private func makeSnapshot(componentStatus: String, incidents: [Incident]) -> OpenAIStatusSnapshot {
    let page = StatusPage(id: "p", name: "OpenAI", url: "https://status.openai.com/", updatedAt: "now")
    let summary = StatusSummaryResponse(
        page: page,
        status: OverallStatus(
            description: componentStatus == "operational" ? "All Systems Operational" : "Service Outage",
            indicator: componentStatus == "operational" ? "none" : "major"
        ),
        components: [
            ComponentStatus(id: "api", name: "API", status: componentStatus, updatedAt: "now")
        ]
    )
    return OpenAIStatusSnapshot(summary: summary, incidents: IncidentsResponse(page: page, incidents: incidents))
}
}
