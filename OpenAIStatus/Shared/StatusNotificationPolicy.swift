import Foundation

public struct StatusNotificationBaseline: Codable, Sendable, Equatable {
    public let activeIncidentUpdates: [String: String]
    public let componentStatuses: [String: String]

    public init(snapshot: OpenAIStatusSnapshot) {
        activeIncidentUpdates = Dictionary(uniqueKeysWithValues: snapshot.activeIncidents.map { incident in
            let latestUpdateID = incident.incidentUpdates
                .max(by: { $0.displayAt < $1.displayAt })?.id ?? ""
            return (incident.id, latestUpdateID)
        })
        componentStatuses = Dictionary(uniqueKeysWithValues: snapshot.components.map { ($0.id, $0.status) })
    }
}

public struct StatusNotificationSelection: Sendable, Equatable {
    public var notifyNewIncidents: Bool
    public var notifyIncidentUpdates: Bool
    public var notifyComponentOutages: Bool
    public var notifyRecoveries: Bool
    public var monitoredComponentIDs: Set<String>?

    public init(
        notifyNewIncidents: Bool,
        notifyIncidentUpdates: Bool,
        notifyComponentOutages: Bool,
        notifyRecoveries: Bool,
        monitoredComponentIDs: Set<String>? = nil
    ) {
        self.notifyNewIncidents = notifyNewIncidents
        self.notifyIncidentUpdates = notifyIncidentUpdates
        self.notifyComponentOutages = notifyComponentOutages
        self.notifyRecoveries = notifyRecoveries
        self.monitoredComponentIDs = monitoredComponentIDs
    }

    public func monitors(componentID: String) -> Bool {
        monitoredComponentIDs?.contains(componentID) ?? true
    }
}

public struct StatusNotificationChanges: Sendable, Equatable {
    public let newIncidentNames: [String]
    public let updatedIncidentNames: [String]
    public let newlyAffectedComponentNames: [String]
    public let recoveredComponentNames: [String]
    public let resolvedIncidentCount: Int

    public var isEmpty: Bool {
        newIncidentNames.isEmpty
            && updatedIncidentNames.isEmpty
            && newlyAffectedComponentNames.isEmpty
            && recoveredComponentNames.isEmpty
            && resolvedIncidentCount == 0
    }
}

public enum StatusNotificationPolicy {
    public static func changes(
        from previous: StatusNotificationBaseline?,
        to snapshot: OpenAIStatusSnapshot,
        selection: StatusNotificationSelection
    ) -> StatusNotificationChanges {
        let current = StatusNotificationBaseline(snapshot: snapshot)
        let previousIncidentIDs = Set(previous?.activeIncidentUpdates.keys.map { $0 } ?? [])
        let currentIncidentIDs = Set(current.activeIncidentUpdates.keys)

        let newIncidentNames: [String]
        if selection.notifyNewIncidents {
            newIncidentNames = snapshot.activeIncidents
                .filter { !previousIncidentIDs.contains($0.id) }
                .map(\.name)
        } else {
            newIncidentNames = []
        }

        let updatedIncidentNames: [String]
        if selection.notifyIncidentUpdates, let previous {
            updatedIncidentNames = snapshot.activeIncidents
                .filter { incident in
                    guard previousIncidentIDs.contains(incident.id) else { return false }
                    let oldUpdate = previous.activeIncidentUpdates[incident.id] ?? ""
                    let newUpdate = current.activeIncidentUpdates[incident.id] ?? ""
                    return !newUpdate.isEmpty && oldUpdate != newUpdate
                }
                .map(\.name)
        } else {
            updatedIncidentNames = []
        }

        let newlyAffectedComponentNames: [String]
        if selection.notifyComponentOutages {
            newlyAffectedComponentNames = snapshot.components
                .filter { component in
                    guard !component.isOperational, selection.monitors(componentID: component.id) else {
                        return false
                    }
                    guard let previous else { return true }
                    return previous.componentStatuses[component.id]?.lowercased() != component.status.lowercased()
                }
                .map(\.name)
        } else {
            newlyAffectedComponentNames = []
        }

        let recoveredComponentNames: [String]
        let resolvedIncidentCount: Int
        if selection.notifyRecoveries, let previous {
            recoveredComponentNames = snapshot.components
                .filter { component in
                    guard component.isOperational, selection.monitors(componentID: component.id) else {
                        return false
                    }
                    guard let oldStatus = previous.componentStatuses[component.id] else { return false }
                    return oldStatus.lowercased() != "operational"
                }
                .map(\.name)
            resolvedIncidentCount = previousIncidentIDs.subtracting(currentIncidentIDs).count
        } else {
            recoveredComponentNames = []
            resolvedIncidentCount = 0
        }

        return StatusNotificationChanges(
            newIncidentNames: newIncidentNames,
            updatedIncidentNames: updatedIncidentNames,
            newlyAffectedComponentNames: newlyAffectedComponentNames,
            recoveredComponentNames: recoveredComponentNames,
            resolvedIncidentCount: resolvedIncidentCount
        )
    }
}
