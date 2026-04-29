import Foundation

enum DomainValidationError: LocalizedError, Equatable {
    case invalid(issues: [String])

    var errorDescription: String? {
        switch self {
        case .invalid(let issues):
            "Domain-Daten sind ungültig: \(issues.joined(separator: ", "))"
        }
    }

    var issues: [String] {
        switch self {
        case .invalid(let issues):
            issues
        }
    }
}

nonisolated enum DomainValidator {
    static let intensityRange = 1 ... 10

    static func validate(_ episode: Episode) throws {
        try throwIfInvalid(episodeIssues(for: episode))
    }

    static func validate(_ medication: ContinuousMedication) throws {
        try throwIfInvalid(continuousMedicationIssues(for: medication))
    }

    static func validate(_ snapshot: WeatherSnapshot) throws {
        try throwIfInvalid(weatherSnapshotIssues(for: snapshot))
    }

    static func episodeIssues(for episode: Episode, path: String = "episode") -> [String] {
        var issues: [String] = []

        appendDateRangeIssue(start: episode.startedAt, end: episode.endedAt, path: path, startField: "startedAt", endField: "endedAt", into: &issues)

        if !intensityRange.contains(episode.intensity) {
            issues.append("\(path).intensity muss zwischen \(intensityRange.lowerBound) und \(intensityRange.upperBound) liegen")
        }

        for (index, medication) in episode.medications.enumerated() {
            issues.append(contentsOf: medicationEntryIssues(for: medication, path: "\(path).medications[\(index)]"))
        }

        for (index, check) in episode.continuousMedicationChecks.enumerated() {
            issues.append(contentsOf: continuousMedicationCheckIssues(for: check, path: "\(path).continuousMedicationChecks[\(index)]"))
        }

        if let weatherSnapshot = episode.weatherSnapshot {
            issues.append(contentsOf: weatherSnapshotIssues(for: weatherSnapshot, path: "\(path).weatherSnapshot"))
        }

        return issues
    }

    static func medicationEntryIssues(for medication: MedicationEntry, path: String = "medicationEntry") -> [String] {
        var issues: [String] = []

        if medication.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("\(path).name darf nicht leer sein")
        }

        if medication.quantity < 1 {
            issues.append("\(path).quantity muss positiv sein")
        }

        return issues
    }

    static func continuousMedicationIssues(for medication: ContinuousMedication, path: String = "continuousMedication") -> [String] {
        var issues: [String] = []

        if medication.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("\(path).name darf nicht leer sein")
        }

        appendDateRangeIssue(start: medication.startDate, end: medication.endDate, path: path, startField: "startDate", endField: "endDate", into: &issues)
        return issues
    }

    static func continuousMedicationCheckIssues(for check: ContinuousMedicationCheck, path: String = "continuousMedicationCheck") -> [String] {
        if check.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["\(path).name darf nicht leer sein"]
        }

        return []
    }

    static func weatherSnapshotIssues(for snapshot: WeatherSnapshot, path: String = "weatherSnapshot") -> [String] {
        var issues: [String] = []

        if snapshot.condition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("\(path).condition darf nicht leer sein")
        }

        if snapshot.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("\(path).source darf nicht leer sein")
        }

        appendDateRangeIssue(start: snapshot.dayRangeStart, end: snapshot.dayRangeEnd, path: path, startField: "dayRangeStart", endField: "dayRangeEnd", into: &issues)
        appendDateRangeIssue(start: snapshot.contextRangeStart, end: snapshot.contextRangeEnd, path: path, startField: "contextRangeStart", endField: "contextRangeEnd", into: &issues)

        for (index, point) in snapshot.contextPoints.enumerated() {
            if point.condition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("\(path).contextPoints[\(index)].condition darf nicht leer sein")
            }
        }

        return issues
    }

    private static func throwIfInvalid(_ issues: [String]) throws {
        guard issues.isEmpty else {
            throw DomainValidationError.invalid(issues: issues)
        }
    }

    private static func appendDateRangeIssue(
        start: Date?,
        end: Date?,
        path: String,
        startField: String,
        endField: String,
        into issues: inout [String]
    ) {
        guard let start, let end, end < start else {
            return
        }

        issues.append("\(path).\(endField) darf nicht vor \(path).\(startField) liegen")
    }
}
