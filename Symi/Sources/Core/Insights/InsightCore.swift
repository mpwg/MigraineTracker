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
    let period: InsightPeriod
    let dateRange: DateInterval?
    let totalQualifiedEpisodeCount: Int
    let metrics: InsightMetrics
    let emptyState: InsightEmptyState?
    let insights: [Insight]

    init(
        period: InsightPeriod = .thirtyDays,
        dateRange: DateInterval? = nil,
        totalQualifiedEpisodeCount: Int,
        metrics: InsightMetrics = .empty,
        emptyState: InsightEmptyState? = nil,
        insights: [Insight]
    ) {
        self.period = period
        self.dateRange = dateRange
        self.totalQualifiedEpisodeCount = totalQualifiedEpisodeCount
        self.metrics = metrics
        self.emptyState = emptyState
        self.insights = insights
    }

    var heroInsight: Insight? {
        insights.first
    }

    var hasEnoughData: Bool {
        totalQualifiedEpisodeCount >= InsightEngine.minimumQualifiedEpisodeCount
    }
}

enum InsightPeriod: String, CaseIterable, Identifiable, Equatable, Sendable {
    case sevenDays
    case thirtyDays
    case threeMonths

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .sevenDays:
            "7 Tage"
        case .thirtyDays:
            "30 Tage"
        case .threeMonths:
            "3 Monate"
        }
    }

    func startDate(endingAt referenceDate: Date, calendar: Calendar) -> Date {
        let value: Int
        let component: Calendar.Component

        switch self {
        case .sevenDays:
            value = -7
            component = .day
        case .thirtyDays:
            value = -30
            component = .day
        case .threeMonths:
            value = -3
            component = .month
        }

        return calendar.date(byAdding: component, value: value, to: referenceDate) ?? referenceDate
    }
}

struct InsightEmptyState: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case noQualifiedEntries
        case notEnoughQualifiedEntries(required: Int, available: Int)
        case noVisibleInsights
    }

    let reason: Reason
    let title: String
    let message: String
    let requiredEntryCount: Int
    let availableEntryCount: Int
}

struct InsightMetrics: Equatable, Sendable {
    let dayPartSummaries: [InsightDayPartSummary]
    let triggerSummaries: [InsightFrequencySummary]
    let acuteMedicationSummaries: [InsightFrequencySummary]
    let continuousMedicationSummaries: [InsightContinuousMedicationSummary]
    let weatherSummary: InsightWeatherSummary
    let dailyIntensityTrend: [InsightDailyIntensityPoint]

    static let empty = InsightMetrics(
        dayPartSummaries: [],
        triggerSummaries: [],
        acuteMedicationSummaries: [],
        continuousMedicationSummaries: [],
        weatherSummary: .empty,
        dailyIntensityTrend: []
    )
}

struct InsightDayPartSummary: Equatable, Sendable {
    let dayPart: EpisodeDayPart
    let count: Int
    let share: Double
    let averageIntensity: Double
}

struct InsightFrequencySummary: Equatable, Sendable {
    let name: String
    let count: Int
    let share: Double
}

struct InsightContinuousMedicationSummary: Equatable, Sendable {
    let name: String
    let takenCount: Int
    let missedCount: Int
    let totalCheckCount: Int
    let takenShare: Double
}

struct InsightWeatherSummary: Equatable, Sendable {
    let entryCountWithWeather: Int
    let extendedContextCount: Int
    let conditionSummaries: [InsightFrequencySummary]
    let averageTemperature: Double?
    let averageHumidity: Double?
    let averagePressure: Double?
    let averagePrecipitation: Double?

    static let empty = InsightWeatherSummary(
        entryCountWithWeather: 0,
        extendedContextCount: 0,
        conditionSummaries: [],
        averageTemperature: nil,
        averageHumidity: nil,
        averagePressure: nil,
        averagePrecipitation: nil
    )
}

struct InsightDailyIntensityPoint: Equatable, Sendable {
    let day: Date
    let entryCount: Int
    let averageIntensity: Double
    let highestIntensity: Int
}

extension InsightEmptyState {
    init(qualifiedEpisodeCount: Int, minimumCount: Int) {
        if qualifiedEpisodeCount == 0 {
            self = InsightEmptyState(
                reason: .noQualifiedEntries,
                title: "Noch nicht genug Einträge für Muster",
                message: "Wenn du einige Schmerz- oder Migräneeinträge erfasst hast, zeigt Symi hier vorsichtige Hinweise.",
                requiredEntryCount: minimumCount,
                availableEntryCount: qualifiedEpisodeCount
            )
        } else {
            self = InsightEmptyState(
                reason: .notEnoughQualifiedEntries(required: minimumCount, available: qualifiedEpisodeCount),
                title: "Noch nicht genug Einträge für Muster",
                message: "\(qualifiedEpisodeCount) von \(minimumCount) nötigen Schmerz- oder Migräneeinträgen sind vorhanden. Sobald mehr Daten da sind, sucht Symi nach vorsichtigen Mustern.",
                requiredEntryCount: minimumCount,
                availableEntryCount: qualifiedEpisodeCount
            )
        }
    }

    static func noVisibleInsights(qualifiedEpisodeCount: Int, minimumCount: Int) -> InsightEmptyState {
        InsightEmptyState(
            reason: .noVisibleInsights,
            title: "Noch kein vorsichtiges Muster sichtbar",
            message: "Es gibt genug Einträge, aber noch nichts, das in deinen Einträgen auffällig genug ist.",
            requiredEntryCount: minimumCount,
            availableEntryCount: qualifiedEpisodeCount
        )
    }
}

extension InsightMetrics {
    init(aggregate: InsightAggregate) {
        let totalCount = aggregate.qualifiedEpisodes.count
        dayPartSummaries = EpisodeDayPart.allCases.compactMap { dayPart in
            guard let count = aggregate.dayPartCounts[dayPart], count > 0 else {
                return nil
            }

            return InsightDayPartSummary(
                dayPart: dayPart,
                count: count,
                share: totalCount == 0 ? 0 : Double(count) / Double(totalCount),
                averageIntensity: aggregate.dayPartAverageIntensities[dayPart] ?? 0
            )
        }
        triggerSummaries = DataAggregator.frequencySummaries(
            from: aggregate.triggerCounts,
            denominator: totalCount
        )
        acuteMedicationSummaries = DataAggregator.frequencySummaries(
            from: aggregate.acuteMedicationCounts,
            denominator: totalCount
        )
        continuousMedicationSummaries = aggregate.continuousMedicationUsage.values.sorted { lhs, rhs in
            if lhs.totalCheckCount != rhs.totalCheckCount {
                return lhs.totalCheckCount > rhs.totalCheckCount
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        weatherSummary = aggregate.weatherSummary
        dailyIntensityTrend = aggregate.dailyIntensityTrend
    }
}

final class InsightEngine: @unchecked Sendable {
    static let minimumQualifiedEpisodeCount = 5

    private var cachedFingerprint: String?
    private var cachedResult: InsightResult?
    private let cacheLock = NSLock()

    func evaluate(
        episodes: [EpisodeRecord],
        period: InsightPeriod = .thirtyDays,
        referenceDate: Date? = nil,
        calendar: Calendar = .current
    ) -> InsightResult {
        let fingerprint = DataAggregator.fingerprint(
            for: episodes,
            period: period,
            referenceDate: referenceDate,
            calendar: calendar
        )

        cacheLock.lock()
        if fingerprint == cachedFingerprint, let cachedResult {
            cacheLock.unlock()
            return cachedResult
        }
        cacheLock.unlock()

        let aggregate = DataAggregator.aggregate(
            episodes: episodes,
            period: period,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let result: InsightResult
        let metrics = InsightMetrics(aggregate: aggregate)

        if aggregate.qualifiedEpisodes.count < Self.minimumQualifiedEpisodeCount {
            result = InsightResult(
                period: aggregate.period,
                dateRange: aggregate.dateRange,
                totalQualifiedEpisodeCount: aggregate.qualifiedEpisodes.count,
                metrics: metrics,
                emptyState: InsightEmptyState(
                    qualifiedEpisodeCount: aggregate.qualifiedEpisodes.count,
                    minimumCount: Self.minimumQualifiedEpisodeCount
                ),
                insights: []
            )
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

            result = InsightResult(
                period: aggregate.period,
                dateRange: aggregate.dateRange,
                totalQualifiedEpisodeCount: aggregate.qualifiedEpisodes.count,
                metrics: metrics,
                emptyState: insights.isEmpty ? InsightEmptyState.noVisibleInsights(
                    qualifiedEpisodeCount: aggregate.qualifiedEpisodes.count,
                    minimumCount: Self.minimumQualifiedEpisodeCount
                ) : nil,
                insights: insights
            )
        }

        cacheLock.lock()
        cachedFingerprint = fingerprint
        cachedResult = result
        cacheLock.unlock()

        return result
    }
}

enum DataAggregator {
    static func aggregate(
        episodes: [EpisodeRecord],
        period: InsightPeriod,
        referenceDate: Date?,
        calendar: Calendar
    ) -> InsightAggregate {
        let allQualifiedEpisodes = qualifiedEpisodes(from: episodes)
        let effectiveReferenceDate = referenceDate ?? allQualifiedEpisodes.map(\.startedAt).max() ?? Date()
        let periodStart = period.startDate(endingAt: effectiveReferenceDate, calendar: calendar)
        let dateRange = DateInterval(start: periodStart, end: effectiveReferenceDate)
        let qualifiedEpisodes = allQualifiedEpisodes.filter { episode in
            episode.startedAt >= periodStart && episode.startedAt <= effectiveReferenceDate
        }.sorted { lhs, rhs in
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
        let dayPartGroups = Dictionary(grouping: qualifiedEpisodes) { episode in
            EpisodeDayPart(date: episode.startedAt, calendar: calendar)
        }
        let acuteMedicationCounts = qualifiedEpisodes.reduce(into: [String: Int]()) { counts, episode in
            for medication in normalizedMedicationNames(from: episode.medications) {
                counts[medication, default: 0] += 1
            }
        }
        let continuousMedicationUsage = continuousMedicationUsage(from: qualifiedEpisodes)
        let weatherSummary = weatherSummary(from: qualifiedEpisodes)
        let dailyIntensityTrend = dailyIntensityTrend(from: qualifiedEpisodes, calendar: calendar)

        return InsightAggregate(
            period: period,
            dateRange: dateRange,
            qualifiedEpisodes: qualifiedEpisodes,
            averageIntensity: averageIntensity,
            weekdayCounts: weekdayCounts,
            weekdayAverageIntensities: weekdayAverageIntensities,
            triggerCounts: triggerCounts,
            dayPartCounts: dayPartGroups.mapValues(\.count),
            dayPartAverageIntensities: dayPartGroups.mapValues { episodes in
                average(episodes.map { Double($0.intensity) })
            },
            acuteMedicationCounts: acuteMedicationCounts,
            continuousMedicationUsage: continuousMedicationUsage,
            weatherSummary: weatherSummary,
            dailyIntensityTrend: dailyIntensityTrend
        )
    }

    static func fingerprint(
        for episodes: [EpisodeRecord],
        period: InsightPeriod,
        referenceDate: Date?,
        calendar: Calendar
    ) -> String {
        let calendarPart = [
            "\(calendar.identifier)",
            calendar.timeZone.identifier,
            "\(calendar.firstWeekday)",
            period.rawValue,
            referenceDate.map { "\($0.timeIntervalSinceReferenceDate)" } ?? "auto-reference"
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
                    normalizedMedicationNames(from: episode.medications).joined(separator: ","),
                    episode.continuousMedicationChecks.map(checkFingerprint).sorted().joined(separator: ","),
                    weatherFingerprint(from: episode.weather)
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

    static func normalizedMedicationNames(from medications: [MedicationRecord]) -> [String] {
        Array(Set(medications.map { normalizeLabel($0.name) }.filter { !$0.isEmpty })).sorted()
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

    private static func continuousMedicationUsage(
        from episodes: [EpisodeRecord]
    ) -> [String: InsightContinuousMedicationSummary] {
        var buckets: [String: (name: String, taken: Int, missed: Int)] = [:]

        for episode in episodes {
            for check in episode.continuousMedicationChecks {
                let name = normalizeLabel(check.name)
                guard !name.isEmpty else {
                    continue
                }

                var bucket = buckets[name] ?? (name: name, taken: 0, missed: 0)
                if check.wasTaken {
                    bucket.taken += 1
                } else {
                    bucket.missed += 1
                }
                buckets[name] = bucket
            }
        }

        return buckets.mapValues { bucket in
            let total = bucket.taken + bucket.missed
            return InsightContinuousMedicationSummary(
                name: bucket.name,
                takenCount: bucket.taken,
                missedCount: bucket.missed,
                totalCheckCount: total,
                takenShare: total == 0 ? 0 : Double(bucket.taken) / Double(total)
            )
        }
    }

    private static func weatherSummary(from episodes: [EpisodeRecord]) -> InsightWeatherSummary {
        let snapshots = episodes.compactMap(\.weather)
        guard !snapshots.isEmpty else {
            return .empty
        }

        let conditionCounts = snapshots.reduce(into: [String: Int]()) { counts, weather in
            let condition = normalizeLabel(weather.condition)
            guard !condition.isEmpty else {
                return
            }

            counts[condition, default: 0] += 1
        }
        let conditionSummaries = frequencySummaries(from: conditionCounts, denominator: snapshots.count)

        return InsightWeatherSummary(
            entryCountWithWeather: snapshots.count,
            extendedContextCount: snapshots.filter(\.hasExtendedContext).count,
            conditionSummaries: conditionSummaries,
            averageTemperature: averageOptional(snapshots.compactMap(\.temperature)),
            averageHumidity: averageOptional(snapshots.compactMap(\.humidity)),
            averagePressure: averageOptional(snapshots.compactMap(\.pressure)),
            averagePrecipitation: averageOptional(snapshots.compactMap(\.precipitation))
        )
    }

    private static func dailyIntensityTrend(
        from episodes: [EpisodeRecord],
        calendar: Calendar
    ) -> [InsightDailyIntensityPoint] {
        Dictionary(grouping: episodes) { episode in
            calendar.startOfDay(for: episode.startedAt)
        }
        .map { day, episodes in
            InsightDailyIntensityPoint(
                day: day,
                entryCount: episodes.count,
                averageIntensity: average(episodes.map { Double($0.intensity) }),
                highestIntensity: episodes.map(\.intensity).max() ?? 0
            )
        }
        .sorted { $0.day < $1.day }
    }

    static func frequencySummaries(from counts: [String: Int], denominator: Int) -> [InsightFrequencySummary] {
        guard denominator > 0 else {
            return []
        }

        return counts
            .map { name, count in
                InsightFrequencySummary(name: name, count: count, share: Double(count) / Double(denominator))
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private static func averageOptional(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return average(values)
    }

    private static func checkFingerprint(_ check: ContinuousMedicationCheckRecord) -> String {
        [
            check.id.uuidString,
            check.continuousMedicationID.uuidString,
            normalizeLabel(check.name),
            normalizeLabel(check.dosage),
            normalizeLabel(check.frequency),
            "\(check.wasTaken)"
        ].joined(separator: ":")
    }

    private static func weatherFingerprint(from weather: WeatherRecord?) -> String {
        guard let weather else {
            return "no-weather"
        }

        let temperature = weather.temperature.map { String($0) } ?? ""
        let humidity = weather.humidity.map { String($0) } ?? ""
        let pressure = weather.pressure.map { String($0) } ?? ""
        let precipitation = weather.precipitation.map { String($0) } ?? ""
        let weatherCode = weather.weatherCode.map { String($0) } ?? ""
        let hasExtendedContext = String(weather.hasExtendedContext)
        let parts: [String] = [
            "weather",
            String(weather.recordedAt.timeIntervalSinceReferenceDate),
            normalizeLabel(weather.condition),
            temperature,
            humidity,
            pressure,
            precipitation,
            weatherCode,
            hasExtendedContext
        ]

        return parts.joined(separator: ":")
    }
}

struct InsightAggregate: Equatable, Sendable {
    let period: InsightPeriod
    let dateRange: DateInterval
    let qualifiedEpisodes: [EpisodeRecord]
    let averageIntensity: Double
    let weekdayCounts: [Int: Int]
    let weekdayAverageIntensities: [Int: Double]
    let triggerCounts: [String: Int]
    let dayPartCounts: [EpisodeDayPart: Int]
    let dayPartAverageIntensities: [EpisodeDayPart: Double]
    let acuteMedicationCounts: [String: Int]
    let continuousMedicationUsage: [String: InsightContinuousMedicationSummary]
    let weatherSummary: InsightWeatherSummary
    let dailyIntensityTrend: [InsightDailyIntensityPoint]
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
            "Muster erkannt: \(weekdayName(for: weekday))"
        case .trigger(let name, _, _):
            "\(name) häufiger zusammen mit Einträgen"
        case .averageIntensity(let value, _):
            "Muster erkannt: Durchschnitt \(formattedIntensity(value))/10"
        case .trend(let direction, _, _, _):
            direction == .rising ? "Muster erkannt: häufiger höhere Intensität" : "Muster erkannt: häufiger niedrigere Intensität"
        }
    }

    private static func description(for candidate: InsightCandidate, totalCount: Int) -> String {
        switch candidate.payload {
        case .weekday(let weekday, let count, _):
            "\(entryCountText(count)) von \(entryCountText(totalCount)) liegen auf \(weekdayName(for: weekday)). Das ist in deinen Einträgen auffällig, aber keine Vorhersage."
        case .trigger(let name, let count, _):
            "\(name) wurde bei \(entryCountText(count)) von \(entryCountText(totalCount)) notiert. Symi beschreibt nur, was häufiger zusammen mit dokumentierten Einträgen vorkommt."
        case .averageIntensity(let value, _):
            "In deinen Einträgen auffällig: Die dokumentierte Intensität liegt im Durchschnitt bei \(formattedIntensity(value)) von 10."
        case .trend(_, let olderAverage, let newerAverage, _):
            "Muster erkannt: Neuere Einträge liegen im Durchschnitt bei \(formattedIntensity(newerAverage))/10, ältere bei \(formattedIntensity(olderAverage))/10. Das beschreibt nur den dokumentierten Verlauf."
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
