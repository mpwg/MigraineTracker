import Foundation

struct Insight: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let confidence: Double
    let importance: Double
    let category: InsightCategory
    let systemImage: String?
}

enum InsightCategory: String, CaseIterable, Equatable, Sendable {
    case weekdayPattern
    case triggerCorrelation
    case averageIntensity
    case trend

    var displayTitle: String {
        switch self {
        case .weekdayPattern:
            "Wochentag"
        case .triggerCorrelation:
            "Trigger"
        case .averageIntensity:
            "Durchschnitt"
        case .trend:
            "Trend"
        }
    }

    var fallbackSystemImage: String {
        switch self {
        case .weekdayPattern:
            "calendar"
        case .triggerCorrelation:
            "tag"
        case .averageIntensity:
            "gauge.medium"
        case .trend:
            "chart.line.uptrend.xyaxis"
        }
    }
}

struct InsightResult: Equatable, Sendable {
    let totalQualifiedEpisodeCount: Int
    let insights: [Insight]

    var heroInsight: Insight? {
        insights.first
    }

    var hasEnoughData: Bool {
        totalQualifiedEpisodeCount >= InsightEngine.minimumQualifiedEpisodeCount
    }
}

final class InsightEngine: @unchecked Sendable {
    static let minimumQualifiedEpisodeCount = 5

    private var cachedFingerprint: String?
    private var cachedResult: InsightResult?
    private let cacheLock = NSLock()

    func evaluate(episodes: [EpisodeRecord], calendar: Calendar = .current) -> InsightResult {
        let fingerprint = DataAggregator.fingerprint(for: episodes, calendar: calendar)

        cacheLock.lock()
        if fingerprint == cachedFingerprint, let cachedResult {
            cacheLock.unlock()
            return cachedResult
        }
        cacheLock.unlock()

        let aggregate = DataAggregator.aggregate(episodes: episodes, calendar: calendar)
        let result: InsightResult

        if aggregate.qualifiedEpisodes.count < Self.minimumQualifiedEpisodeCount {
            result = InsightResult(totalQualifiedEpisodeCount: aggregate.qualifiedEpisodes.count, insights: [])
        } else {
            let insights = PatternDetector.detect(in: aggregate)
                .compactMap { InsightScorer.score($0, aggregate: aggregate) }
                .filter { $0.confidence >= InsightScorer.confidenceThreshold && $0.importance >= InsightScorer.importanceThreshold }
                .sorted { lhs, rhs in
                    if lhs.sortScore != rhs.sortScore {
                        return lhs.sortScore > rhs.sortScore
                    }

                    if lhs.confidence != rhs.confidence {
                        return lhs.confidence > rhs.confidence
                    }

                    return lhs.insight.title.localizedStandardCompare(rhs.insight.title) == .orderedAscending
                }
                .map(\.insight)

            result = InsightResult(totalQualifiedEpisodeCount: aggregate.qualifiedEpisodes.count, insights: insights)
        }

        cacheLock.lock()
        cachedFingerprint = fingerprint
        cachedResult = result
        cacheLock.unlock()

        return result
    }
}

enum DataAggregator {
    static func aggregate(episodes: [EpisodeRecord], calendar: Calendar) -> InsightAggregate {
        let qualifiedEpisodes = qualifiedEpisodes(from: episodes).sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt < rhs.startedAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        let intensities = qualifiedEpisodes.map(\.intensity)
        let averageIntensity = average(intensities.map(Double.init))
        let weekdayGroups = Dictionary(grouping: qualifiedEpisodes) { episode in
            calendar.component(.weekday, from: episode.startedAt)
        }
        let weekdayCounts = weekdayGroups.mapValues(\.count)
        let weekdayAverageIntensities = weekdayGroups.mapValues { episodes in
            average(episodes.map { Double($0.intensity) })
        }

        let triggerCounts = qualifiedEpisodes.reduce(into: [String: Int]()) { counts, episode in
            for trigger in normalizedTriggers(from: episode) {
                counts[trigger, default: 0] += 1
            }
        }

        return InsightAggregate(
            qualifiedEpisodes: qualifiedEpisodes,
            averageIntensity: averageIntensity,
            weekdayCounts: weekdayCounts,
            weekdayAverageIntensities: weekdayAverageIntensities,
            triggerCounts: triggerCounts
        )
    }

    static func fingerprint(for episodes: [EpisodeRecord], calendar: Calendar) -> String {
        let calendarPart = [
            "\(calendar.identifier)",
            calendar.timeZone.identifier,
            "\(calendar.firstWeekday)"
        ].joined(separator: "|")

        let episodeParts = qualifiedEpisodes(from: episodes)
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { episode in
                [
                    episode.id.uuidString,
                    "\(episode.startedAt.timeIntervalSinceReferenceDate)",
                    "\(episode.updatedAt.timeIntervalSinceReferenceDate)",
                    episode.type.rawValue,
                    "\(episode.intensity)",
                    normalizedTriggers(from: episode).joined(separator: ","),
                    episode.weather == nil ? "no-weather" : "weather"
                ].joined(separator: "|")
            }

        return ([calendarPart] + episodeParts).joined(separator: "\n")
    }

    static func qualifiedEpisodes(from episodes: [EpisodeRecord]) -> [EpisodeRecord] {
        episodes.filter { episode in
            !episode.isDeleted && (episode.type == .migraine || episode.type == .headache)
        }
    }

    static func normalizedTriggers(from episode: EpisodeRecord) -> [String] {
        Array(Set(episode.triggers.map(normalizeLabel).filter { !$0.isEmpty })).sorted()
    }

    static func normalizeLabel(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(0, +) / Double(values.count)
    }
}

struct InsightAggregate: Equatable, Sendable {
    let qualifiedEpisodes: [EpisodeRecord]
    let averageIntensity: Double
    let weekdayCounts: [Int: Int]
    let weekdayAverageIntensities: [Int: Double]
    let triggerCounts: [String: Int]
}

enum PatternDetector {
    static func detect(in aggregate: InsightAggregate) -> [InsightCandidate] {
        [
            weekdayPattern(in: aggregate),
            triggerCorrelation(in: aggregate),
            averageIntensity(in: aggregate),
            trend(in: aggregate)
        ].compactMap { $0 }
    }

    private static func weekdayPattern(in aggregate: InsightAggregate) -> InsightCandidate? {
        guard
            let match = aggregate.weekdayCounts.sorted(by: weekdaySort).first,
            match.value >= 2
        else {
            return nil
        }

        let totalCount = aggregate.qualifiedEpisodes.count
        let share = Double(match.value) / Double(totalCount)
        let randomWeekdayBaseline = 1.0 / 7.0
        let patternStrength = clamped((share - randomWeekdayBaseline) / (1.0 - randomWeekdayBaseline))
        let matchingAverage = aggregate.weekdayAverageIntensities[match.key] ?? aggregate.averageIntensity

        return InsightCandidate(
            category: .weekdayPattern,
            key: "\(match.key)",
            supportCount: match.value,
            patternStrength: patternStrength,
            relevantAverageIntensity: matchingAverage,
            payload: .weekday(weekday: match.key, count: match.value, share: share)
        )
    }

    private static func triggerCorrelation(in aggregate: InsightAggregate) -> InsightCandidate? {
        guard
            let match = aggregate.triggerCounts.sorted(by: triggerSort).first,
            match.value >= 2
        else {
            return nil
        }

        let totalCount = aggregate.qualifiedEpisodes.count
        let share = Double(match.value) / Double(totalCount)
        let matchingAverage = DataAggregator.average(
            aggregate.qualifiedEpisodes
                .filter { DataAggregator.normalizedTriggers(from: $0).contains(match.key) }
                .map { Double($0.intensity) }
        )

        return InsightCandidate(
            category: .triggerCorrelation,
            key: DataAggregator.normalizeLabel(match.key).lowercased(),
            supportCount: match.value,
            patternStrength: clamped(share),
            relevantAverageIntensity: matchingAverage,
            payload: .trigger(name: match.key, count: match.value, share: share)
        )
    }

    private static func averageIntensity(in aggregate: InsightAggregate) -> InsightCandidate? {
        InsightCandidate(
            category: .averageIntensity,
            key: "all",
            supportCount: aggregate.qualifiedEpisodes.count,
            patternStrength: clamped(aggregate.averageIntensity / 10.0),
            relevantAverageIntensity: aggregate.averageIntensity,
            payload: .averageIntensity(value: aggregate.averageIntensity, count: aggregate.qualifiedEpisodes.count)
        )
    }

    private static func trend(in aggregate: InsightAggregate) -> InsightCandidate? {
        let episodes = aggregate.qualifiedEpisodes
        guard episodes.count >= InsightEngine.minimumQualifiedEpisodeCount else {
            return nil
        }

        let olderCount = episodes.count / 2
        let olderEpisodes = Array(episodes.prefix(olderCount))
        let newerEpisodes = Array(episodes.suffix(episodes.count - olderCount))
        let olderAverage = DataAggregator.average(olderEpisodes.map { Double($0.intensity) })
        let newerAverage = DataAggregator.average(newerEpisodes.map { Double($0.intensity) })
        let difference = newerAverage - olderAverage

        guard abs(difference) >= 1.0 else {
            return nil
        }

        let direction: TrendDirection = difference > 0 ? .rising : .falling

        return InsightCandidate(
            category: .trend,
            key: direction.rawValue,
            supportCount: episodes.count,
            patternStrength: clamped(abs(difference) / 3.0),
            relevantAverageIntensity: max(olderAverage, newerAverage),
            payload: .trend(
                direction: direction,
                olderAverage: olderAverage,
                newerAverage: newerAverage,
                difference: difference
            )
        )
    }

    private static func weekdaySort(lhs: (key: Int, value: Int), rhs: (key: Int, value: Int)) -> Bool {
        if lhs.value != rhs.value {
            return lhs.value > rhs.value
        }

        return lhs.key < rhs.key
    }

    private static func triggerSort(lhs: (key: String, value: Int), rhs: (key: String, value: Int)) -> Bool {
        if lhs.value != rhs.value {
            return lhs.value > rhs.value
        }

        return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct InsightCandidate: Equatable, Sendable {
    let category: InsightCategory
    let key: String
    let supportCount: Int
    let patternStrength: Double
    let relevantAverageIntensity: Double
    let payload: InsightPayload
}

enum InsightPayload: Equatable, Sendable {
    case weekday(weekday: Int, count: Int, share: Double)
    case trigger(name: String, count: Int, share: Double)
    case averageIntensity(value: Double, count: Int)
    case trend(direction: TrendDirection, olderAverage: Double, newerAverage: Double, difference: Double)
}

enum TrendDirection: String, Equatable, Sendable {
    case rising
    case falling
}

enum InsightScorer {
    static let confidenceThreshold = 0.50
    static let importanceThreshold = 0.40

    static func score(_ candidate: InsightCandidate, aggregate: InsightAggregate) -> ScoredInsight? {
        let sampleCoverage = min(1, Double(candidate.supportCount) / 8.0)
        let confidence = clamped((0.6 * candidate.patternStrength) + (0.4 * sampleCoverage))
        let intensityFactor = clamped(candidate.relevantAverageIntensity / 10.0)
        let importance: Double

        if candidate.category == .averageIntensity {
            importance = intensityFactor
        } else {
            importance = clamped((0.55 * candidate.patternStrength) + (0.45 * intensityFactor))
        }

        let insight = InsightFormatter.format(
            candidate,
            aggregate: aggregate,
            confidence: confidence,
            importance: importance
        )
        let sortScore = (0.6 * importance) + (0.4 * confidence)

        return ScoredInsight(insight: insight, confidence: confidence, importance: importance, sortScore: sortScore)
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct ScoredInsight: Equatable, Sendable {
    let insight: Insight
    let confidence: Double
    let importance: Double
    let sortScore: Double
}

enum InsightFormatter {
    static func format(
        _ candidate: InsightCandidate,
        aggregate: InsightAggregate,
        confidence: Double,
        importance: Double
    ) -> Insight {
        Insight(
            id: "\(candidate.category.rawValue):\(candidate.key)",
            title: title(for: candidate),
            description: description(for: candidate, totalCount: aggregate.qualifiedEpisodes.count),
            confidence: confidence,
            importance: importance,
            category: candidate.category,
            systemImage: systemImage(for: candidate)
        )
    }

    private static func title(for candidate: InsightCandidate) -> String {
        switch candidate.payload {
        case .weekday(let weekday, _, _):
            "Auffälliger \(weekdayName(for: weekday))"
        case .trigger(let name, _, _):
            "\(name) fällt öfter auf"
        case .averageIntensity(let value, _):
            "Durchschnitt \(formattedIntensity(value))/10"
        case .trend(let direction, _, _, _):
            direction == .rising ? "Intensität steigt" : "Intensität fällt"
        }
    }

    private static func description(for candidate: InsightCandidate, totalCount: Int) -> String {
        switch candidate.payload {
        case .weekday(let weekday, let count, _):
            "\(entryCountText(count)) von \(entryCountText(totalCount)) liegen auf \(weekdayName(for: weekday)). Das ist ein Muster in deinen bisherigen Einträgen, keine Vorhersage."
        case .trigger(let name, let count, _):
            "\(name) wurde bei \(entryCountText(count)) von \(entryCountText(totalCount)) notiert. Symi wertet das als Häufung, nicht als Ursache."
        case .averageIntensity(let value, let count):
            "Die durchschnittliche Intensität deiner \(entryCountText(count)) liegt bei \(formattedIntensity(value)) von 10."
        case .trend(_, let olderAverage, let newerAverage, _):
            "Neuere Einträge liegen im Durchschnitt bei \(formattedIntensity(newerAverage))/10, ältere bei \(formattedIntensity(olderAverage))/10. Das beschreibt nur den Verlauf deiner dokumentierten Einträge."
        }
    }

    private static func systemImage(for candidate: InsightCandidate) -> String {
        switch candidate.payload {
        case .trigger(let name, _, _):
            triggerSystemImage(for: name)
        default:
            candidate.category.fallbackSystemImage
        }
    }

    private static func triggerSystemImage(for name: String) -> String {
        switch name.lowercased() {
        case "stress", "erhöhte arbeitsbelastung":
            "brain.head.profile"
        case "wetter":
            "cloud.sun"
        case "schlaf", "schlafdauer":
            "moon"
        case "ernährung":
            "fork.knife.circle"
        case "bildschirmzeit":
            "ipad.landscape.and.iphone"
        case "zyklus", "regel":
            "drop"
        case "bewegung", "sport":
            "figure.run"
        case "flüssigkeit":
            "waterbottle"
        default:
            "tag"
        }
    }

    private static func weekdayName(for weekday: Int) -> String {
        switch weekday {
        case 1:
            "Sonntag"
        case 2:
            "Montag"
        case 3:
            "Dienstag"
        case 4:
            "Mittwoch"
        case 5:
            "Donnerstag"
        case 6:
            "Freitag"
        case 7:
            "Samstag"
        default:
            "ein Wochentag"
        }
    }

    private static func formattedIntensity(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10

        if rounded.rounded() == rounded {
            return "\(Int(rounded))"
        }

        let tenths = Int((rounded * 10).rounded())
        return "\(tenths / 10),\(abs(tenths % 10))"
    }

    private static func entryCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "Eintrag" : "Einträge")"
    }
}
