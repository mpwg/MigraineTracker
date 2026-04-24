import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

final class AppleHealthKitService: HealthService {
    let readDefinitions = HealthDataCatalog.readDefinitions
    let writeDefinitions = HealthDataCatalog.writeDefinitions

    private let preferences: HealthTypePreferences

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    init(preferences: HealthTypePreferences = HealthTypePreferences()) {
        self.preferences = preferences
    }

    func authorizationSnapshot() -> HealthAuthorizationSnapshot {
        guard Self.isAvailable else {
            return .unavailable
        }

        let readTypes = preferences.enabledTypes(for: .read, definitions: readDefinitions)
        let writeTypes = preferences.enabledTypes(for: .write, definitions: writeDefinitions)

        return HealthAuthorizationSnapshot(
            isAvailable: true,
            isReadEnabled: preferences.hasRequestedAuthorization(for: .read) && !readTypes.isEmpty,
            isWriteEnabled: preferences.hasRequestedAuthorization(for: .write) && !writeTypes.isEmpty,
            enabledReadTypes: readTypes,
            enabledWriteTypes: writeTypes,
            lastErrorMessage: nil
        )
    }

    func setEnabled(_ enabled: Bool, for type: HealthDataTypeID, direction: HealthDataDirection) {
        preferences.setEnabled(enabled, type: type, direction: direction)
    }

    func requestReadAuthorization() async throws {
        guard Self.isAvailable else {
            throw HealthIntegrationError.unavailable
        }

        #if canImport(HealthKit)
        try await healthStore.requestAuthorization(toShare: [], read: readObjectTypes())
        preferences.markAuthorizationRequested(for: .read)
        #endif
    }

    func requestWriteAuthorization() async throws {
        guard Self.isAvailable else {
            throw HealthIntegrationError.unavailable
        }

        #if canImport(HealthKit)
        try await healthStore.requestAuthorization(toShare: writeSampleTypes(), read: [])
        preferences.markAuthorizationRequested(for: .write)
        #endif
    }

    func contextSnapshot(for draft: EpisodeDraft) async throws -> HealthContextSnapshotData? {
        guard authorizationSnapshot().isReadEnabled else {
            return nil
        }

        #if canImport(HealthKit)
        let enabledTypes = authorizationSnapshot().enabledReadTypes
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: draft.startedAt)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? draft.startedAt
        let sleepStart = calendar.date(byAdding: .hour, value: -18, to: draft.startedAt) ?? dayStart

        async let sleepMinutes = enabledTypes.contains(.sleep) ? sleepMinutes(from: sleepStart, to: draft.startedAt) : nil
        async let stepCount = enabledTypes.contains(.steps) ? stepCount(from: dayStart, to: Swift.min(draft.startedAt, dayEnd)) : nil
        async let averageHeartRate = enabledTypes.contains(.heartRate) ? averageHeartRate(from: draft.startedAt.addingTimeInterval(-3_600), to: draft.startedAt.addingTimeInterval(3_600)) : nil
        async let restingHeartRate = enabledTypes.contains(.restingHeartRate) ? latestQuantityValue(typeID: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: dayStart, to: dayEnd) : nil
        async let hrv = enabledTypes.contains(.heartRateVariability) ? latestQuantityValue(typeID: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: dayStart, to: dayEnd) : nil
        async let menstrualFlow = enabledTypes.contains(.menstrualFlow) ? latestMenstrualFlow(from: dayStart, to: dayEnd) : nil
        async let symptoms = symptomSamples(enabledTypes: enabledTypes, from: dayStart, to: dayEnd)

        let snapshot = HealthContextSnapshotData(
            recordedAt: .now,
            source: "Apple Health",
            sleepMinutes: try await sleepMinutes,
            stepCount: try await stepCount,
            averageHeartRate: try await averageHeartRate,
            restingHeartRate: try await restingHeartRate,
            heartRateVariability: try await hrv,
            menstrualFlow: try await menstrualFlow,
            symptoms: try await symptoms
        )

        return snapshot.hasVisibleData ? snapshot : nil
        #else
        return nil
        #endif
    }

    func writeEpisode(id: UUID, draft: EpisodeDraft) async throws {
        guard authorizationSnapshot().isWriteEnabled else {
            return
        }

        #if canImport(HealthKit)
        let enabledTypes = authorizationSnapshot().enabledWriteTypes
        var samples: [HKSample] = []

        if enabledTypes.contains(.headache), let sample = symptomSample(
            typeID: .headache,
            type: .headache,
            id: id,
            draft: draft
        ) {
            samples.append(sample)
        }

        if enabledTypes.contains(.nausea), draft.selectedSymptoms.contains("Übelkeit"), let sample = symptomSample(
            typeID: .nausea,
            type: .nausea,
            id: id,
            draft: draft
        ) {
            samples.append(sample)
        }

        guard !samples.isEmpty else {
            return
        }

        try await healthStore.save(samples)
        #endif
    }

    private static var isAvailable: Bool {
        #if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }

    #if canImport(HealthKit)
    private func readObjectTypes() -> Set<HKObjectType> {
        authorizationSnapshot().enabledReadTypes.compactMap(Self.objectType(for:)).reduce(into: Set<HKObjectType>()) { result, type in
            result.insert(type)
        }
    }

    private func writeSampleTypes() -> Set<HKSampleType> {
        authorizationSnapshot().enabledWriteTypes.compactMap(Self.sampleType(for:)).reduce(into: Set<HKSampleType>()) { result, type in
            result.insert(type)
        }
    }

    private static func objectType(for type: HealthDataTypeID) -> HKObjectType? {
        sampleType(for: type)
    }

    private static func sampleType(for type: HealthDataTypeID) -> HKSampleType? {
        switch type {
        case .sleep:
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .steps:
            HKObjectType.quantityType(forIdentifier: .stepCount)
        case .heartRate:
            HKObjectType.quantityType(forIdentifier: .heartRate)
        case .restingHeartRate:
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .heartRateVariability:
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .menstrualFlow:
            if #available(iOS 18.0, *) {
                HKObjectType.categoryType(forIdentifier: .menstrualFlow)
            } else {
                nil
            }
        case .headache:
            HKObjectType.categoryType(forIdentifier: .headache)
        case .nausea:
            HKObjectType.categoryType(forIdentifier: .nausea)
        case .dizziness:
            HKObjectType.categoryType(forIdentifier: .dizziness)
        case .fatigue:
            HKObjectType.categoryType(forIdentifier: .fatigue)
        }
    }

    private func sleepMinutes(from start: Date, to end: Date) async throws -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let samples = try await categorySamples(type: type, from: start, to: end)
        let asleepValues = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let seconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        return seconds > 0 ? seconds / 60 : nil
    }

    private func stepCount(from start: Date, to end: Date) async throws -> Int? {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }

        let value = try await cumulativeQuantity(type: type, unit: .count(), from: start, to: end)
        return value.map { Int($0.rounded()) }
    }

    private func averageHeartRate(from start: Date, to end: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        return try await averageQuantity(type: type, unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: end)
    }

    private func latestQuantityValue(typeID: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: typeID) else {
            return nil
        }

        let samples = try await quantitySamples(type: type, from: start, to: end, limit: 1)
        return samples.first?.quantity.doubleValue(for: unit)
    }

    private func latestMenstrualFlow(from start: Date, to end: Date) async throws -> String? {
        guard #available(iOS 18.0, *) else {
            return nil
        }

        guard let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else {
            return nil
        }

        return try await categorySamples(type: type, from: start, to: end).last.map { sample in
            switch sample.value {
            case HKCategoryValueVaginalBleeding.light.rawValue:
                "Leicht"
            case HKCategoryValueVaginalBleeding.medium.rawValue:
                "Mittel"
            case HKCategoryValueVaginalBleeding.heavy.rawValue:
                "Stark"
            case HKCategoryValueVaginalBleeding.unspecified.rawValue:
                "Nicht angegeben"
            default:
                "Erfasst"
            }
        }
    }

    private func symptomSamples(enabledTypes: Set<HealthDataTypeID>, from start: Date, to end: Date) async throws -> [HealthSymptomSampleData] {
        let symptomTypes: [(HealthDataTypeID, HKCategoryTypeIdentifier)] = [
            (.headache, .headache),
            (.nausea, .nausea),
            (.dizziness, .dizziness),
            (.fatigue, .fatigue)
        ]

        var result: [HealthSymptomSampleData] = []
        for (typeID, categoryID) in symptomTypes where enabledTypes.contains(typeID) {
            guard let type = HKObjectType.categoryType(forIdentifier: categoryID) else {
                continue
            }

            let samples = try await categorySamples(type: type, from: start, to: end)
            result.append(contentsOf: samples.map {
                HealthSymptomSampleData(
                    type: typeID,
                    severity: Self.severityLabel(for: $0.value),
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    source: $0.sourceRevision.source.name
                )
            })
        }

        return result.sorted { $0.startDate < $1.startDate }
    }

    private func symptomSample(typeID: HKCategoryTypeIdentifier, type: HealthDataTypeID, id: UUID, draft: EpisodeDraft) -> HKCategorySample? {
        guard let categoryType = HKObjectType.categoryType(forIdentifier: typeID) else {
            return nil
        }

        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: "\(id.uuidString):\(type.rawValue)",
            HKMetadataKeySyncIdentifier: "eu.mpwg.MigraineTracker.episode.\(id.uuidString).\(type.rawValue)",
            HKMetadataKeySyncVersion: Int(draft.startedAt.timeIntervalSince1970),
            HKMetadataKeyTimeZone: TimeZone.current.identifier,
            HKMetadataKeyWasUserEntered: true
        ]

        return HKCategorySample(
            type: categoryType,
            value: Self.severityValue(forIntensity: draft.intensity),
            start: draft.startedAt,
            end: draft.endedAtEnabled ? draft.endedAt : draft.startedAt,
            metadata: metadata
        )
    }

    private func cumulativeQuantity(type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func averageQuantity(type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: statistics?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func quantitySamples(type: HKQuantityType, from start: Date, to end: Date, limit: Int) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func categorySamples(type: HKCategoryType, from start: Date, to end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private static func severityValue(forIntensity intensity: Int) -> Int {
        switch intensity {
        case ...3:
            HKCategoryValueSeverity.mild.rawValue
        case 4...6:
            HKCategoryValueSeverity.moderate.rawValue
        default:
            HKCategoryValueSeverity.severe.rawValue
        }
    }

    private static func severityLabel(for value: Int) -> String {
        switch value {
        case HKCategoryValueSeverity.mild.rawValue:
            "Leicht"
        case HKCategoryValueSeverity.moderate.rawValue:
            "Mittel"
        case HKCategoryValueSeverity.severe.rawValue:
            "Stark"
        case HKCategoryValueSeverity.notPresent.rawValue:
            "Nicht vorhanden"
        default:
            "Nicht angegeben"
        }
    }
    #endif
}

final class HealthTypePreferences {
    private let defaults: UserDefaults
    private let keyPrefix = "health.type.enabled"
    private let authorizationKeyPrefix = "health.authorization.requested"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func enabledTypes(for direction: HealthDataDirection, definitions: [HealthDataTypeDefinition]) -> Set<HealthDataTypeID> {
        Set(definitions.compactMap { definition in
            isEnabled(definition.id, direction: direction, defaultValue: definition.defaultEnabled) ? definition.id : nil
        })
    }

    func setEnabled(_ enabled: Bool, type: HealthDataTypeID, direction: HealthDataDirection) {
        defaults.set(enabled, forKey: key(for: type, direction: direction))
    }

    func hasRequestedAuthorization(for direction: HealthDataDirection) -> Bool {
        defaults.bool(forKey: authorizationKey(for: direction))
    }

    func markAuthorizationRequested(for direction: HealthDataDirection) {
        defaults.set(true, forKey: authorizationKey(for: direction))
    }

    private func isEnabled(_ type: HealthDataTypeID, direction: HealthDataDirection, defaultValue: Bool) -> Bool {
        let key = key(for: type, direction: direction)
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }

    private func key(for type: HealthDataTypeID, direction: HealthDataDirection) -> String {
        "\(keyPrefix).\(direction.rawValue).\(type.rawValue)"
    }

    private func authorizationKey(for direction: HealthDataDirection) -> String {
        "\(authorizationKeyPrefix).\(direction.rawValue)"
    }
}
