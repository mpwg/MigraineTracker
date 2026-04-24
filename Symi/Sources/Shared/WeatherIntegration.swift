import CoreLocation
import Foundation
import SwiftData
import WeatherKit

struct WeatherSnapshotData: Equatable, Sendable {
    let recordedAt: Date
    let condition: String
    let temperature: Double?
    let humidity: Double?
    let pressure: Double?
    let precipitation: Double?
    let weatherCode: Int?
    let source: String

    init(
        recordedAt: Date,
        condition: String,
        temperature: Double?,
        humidity: Double?,
        pressure: Double?,
        precipitation: Double?,
        weatherCode: Int?,
        source: String
    ) {
        self.recordedAt = recordedAt
        self.condition = condition
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.precipitation = precipitation
        self.weatherCode = weatherCode
        self.source = source
    }

    init(record: WeatherRecord) {
        self.init(
            recordedAt: record.recordedAt,
            condition: record.condition,
            temperature: record.temperature,
            humidity: record.humidity,
            pressure: record.pressure,
            precipitation: record.precipitation,
            weatherCode: record.weatherCode,
            source: record.source
        )
    }
}

enum WeatherAttribution {
    static let providerName = "Apple Weather"
    static let providerURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
    static let sourceDescription = "Wetterdaten von Apple Weather über WeatherKit."
    static let modifiedSourceDescription = "Wetterdaten von Apple Weather über WeatherKit. Die Werte werden als Snapshot für den Episodenzeitpunkt gespeichert."

    static let fallback = WeatherAttributionData(
        serviceName: providerName,
        legalPageURL: providerURL,
        combinedMarkDarkURL: nil,
        combinedMarkLightURL: nil,
        legalAttributionText: nil
    )

    static func load() async -> WeatherAttributionData {
        do {
            let attribution = try await WeatherKit.WeatherService.shared.attribution
            return WeatherAttributionData(
                serviceName: attribution.serviceName,
                legalPageURL: attribution.legalPageURL,
                combinedMarkDarkURL: attribution.combinedMarkDarkURL,
                combinedMarkLightURL: attribution.combinedMarkLightURL,
                legalAttributionText: attribution.legalAttributionText
            )
        } catch {
            return fallback
        }
    }
}

struct WeatherAttributionData: Equatable, Sendable {
    let serviceName: String
    let legalPageURL: URL
    let combinedMarkDarkURL: URL?
    let combinedMarkLightURL: URL?
    let legalAttributionText: String?
}

protocol WeatherService {
    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherSnapshotData?
}

@MainActor
protocol LocationService {
    func requestApproximateLocation() async throws -> CLLocation
}

enum LocationServiceError: LocalizedError {
    case servicesDisabled
    case authorizationDenied
    case unableToDetermineLocation

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            "Standortdienste sind deaktiviert."
        case .authorizationDenied:
            "Ohne Standortfreigabe kann das Wetter nicht automatisch geladen werden."
        case .unableToDetermineLocation:
            "Der ungefähre Standort konnte nicht ermittelt werden."
        }
    }
}

enum WeatherServiceError: LocalizedError {
    case noHourlyData
    case noMatchingHour
    case weatherKitAuthentication

    var errorDescription: String? {
        switch self {
        case .noHourlyData:
            "Die Wetterquelle hat keine stündlichen Daten geliefert."
        case .noMatchingHour:
            "Für den Episodenzeitpunkt wurde kein passender Wetterwert gefunden."
        case .weatherKitAuthentication:
            "WeatherKit konnte nicht authentifizieren. Prüfe, ob WeatherKit im Apple Developer Portal für diese App-ID aktiviert ist und ob das Provisioning Profile aktualisiert wurde."
        }
    }
}

@MainActor
final class SystemLocationService: NSObject, LocationService, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func requestApproximateLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                continuation.resume(throwing: LocationServiceError.authorizationDenied)
                self.continuation = nil
            @unknown default:
                continuation.resume(throwing: LocationServiceError.unableToDetermineLocation)
                self.continuation = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation else {
            return
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self.continuation = continuation
            manager.requestLocation()
        case .denied, .restricted:
            continuation.resume(throwing: LocationServiceError.authorizationDenied)
            self.continuation = nil
        case .notDetermined:
            break
        @unknown default:
            continuation.resume(throwing: LocationServiceError.unableToDetermineLocation)
            self.continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let continuation else {
            return
        }

        continuation.resume(returning: location)
        self.continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        guard let continuation else {
            return
        }

        if let error = error as? CLError, error.code == .denied {
            let authorizationStatus = manager.authorizationStatus
            let mappedError: LocationServiceError =
                authorizationStatus == .denied || authorizationStatus == .restricted
                ? .authorizationDenied
                : .servicesDisabled
            continuation.resume(throwing: mappedError)
        } else {
            continuation.resume(throwing: error)
        }
        self.continuation = nil
    }
}

struct AppleWeatherKitWeatherService: WeatherService {
    private let service = WeatherKit.WeatherService.shared
    private let earliestHourlyDate = Date(timeIntervalSince1970: 1_627_776_000)

    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherSnapshotData? {
        if date > .now {
            throw EpisodeSaveError.futureDate
        }

        guard date >= earliestHourlyDate else {
            return nil
        }

        let interval = hourlyInterval(containing: date)
        let hourlyForecast: Forecast<HourWeather>
        do {
            hourlyForecast = try await service.weather(
                for: location,
                including: .hourly(startDate: interval.start, endDate: interval.end)
            )
        } catch {
            if isWeatherKitAuthenticationError(error) {
                throw WeatherServiceError.weatherKitAuthentication
            }
            throw error
        }

        guard let matchedHour = hourlyForecast.forecast.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else {
            throw WeatherServiceError.noMatchingHour
        }

        return WeatherSnapshotData(
            recordedAt: matchedHour.date,
            condition: WeatherConditionMapper.description(for: matchedHour.condition),
            temperature: matchedHour.temperature.converted(to: .celsius).value,
            humidity: matchedHour.humidity * 100,
            pressure: matchedHour.pressure.converted(to: .hectopascals).value,
            precipitation: matchedHour.precipitationAmount.converted(to: .millimeters).value,
            weatherCode: nil,
            source: WeatherAttribution.providerName
        )
    }

    private func hourlyInterval(containing date: Date) -> DateInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86_400)
        return DateInterval(start: startOfDay, end: endOfDay)
    }

    private func isWeatherKitAuthenticationError(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain.contains("WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors")
            || nsError.localizedDescription.contains("WDSJWTAuthenticator")
    }
}

enum WeatherConditionMapper {
    static func description(for condition: WeatherCondition) -> String {
        switch condition {
        case .blizzard:
            return "Schneesturm"
        case .blowingDust:
            return "Staubwind"
        case .blowingSnow:
            return "Schneetreiben"
        case .breezy:
            return "Windig"
        case .clear:
            return "Klar"
        case .cloudy:
            return "Bedeckt"
        case .drizzle:
            return "Nieselregen"
        case .flurries:
            return "Leichter Schneefall"
        case .foggy:
            return "Nebelig"
        case .freezingDrizzle:
            return "Gefrierender Nieselregen"
        case .freezingRain:
            return "Gefrierender Regen"
        case .frigid:
            return "Frostig"
        case .hail:
            return "Hagel"
        case .haze:
            return "Dunstig"
        case .heavyRain:
            return "Starker Regen"
        case .heavySnow:
            return "Starker Schneefall"
        case .hot:
            return "Heiß"
        case .hurricane:
            return "Orkan"
        case .isolatedThunderstorms:
            return "Vereinzelte Gewitter"
        case .mostlyClear:
            return "Überwiegend klar"
        case .mostlyCloudy:
            return "Überwiegend bewölkt"
        case .partlyCloudy:
            return "Teilweise bewölkt"
        case .rain:
            return "Regen"
        case .scatteredThunderstorms:
            return "Verstreute Gewitter"
        case .sleet:
            return "Schneeregen"
        case .smoky:
            return "Rauchig"
        case .snow:
            return "Schnee"
        case .strongStorms:
            return "Schwere Gewitter"
        case .sunFlurries:
            return "Schneeschauer mit Sonne"
        case .sunShowers:
            return "Regenschauer mit Sonne"
        case .thunderstorms:
            return "Gewitter"
        case .tropicalStorm:
            return "Tropischer Sturm"
        case .windy:
            return "Windig"
        case .wintryMix:
            return "Winterlicher Niederschlag"
        @unknown default:
            return "Unbekannt"
        }
    }
}

enum WeatherCodeMapper {
    static func description(for code: Int?) -> String {
        guard let code else {
            return "Nicht verfügbar"
        }

        switch code {
        case 0: return "Klar"
        case 1: return "Überwiegend klar"
        case 2: return "Teilweise bewölkt"
        case 3: return "Bedeckt"
        case 45, 48: return "Nebelig"
        case 51, 53, 55: return "Nieselregen"
        case 56, 57: return "Gefrierender Nieselregen"
        case 61, 63, 65: return "Regen"
        case 66, 67: return "Gefrierender Regen"
        case 71, 73, 75, 77: return "Schnee"
        case 80, 81, 82: return "Regenschauer"
        case 85, 86: return "Schneeschauer"
        case 95: return "Gewitter"
        case 96, 99: return "Gewitter mit Hagel"
        default: return "Unbekannt"
        }
    }
}
@MainActor
final class WeatherBackfillService {
    private struct BackfillCandidate {
        let modelID: PersistentIdentifier
        let startedAt: Date
    }

    private struct CandidatePage {
        let scannedCount: Int
        let candidates: [BackfillCandidate]
    }

    private let modelContainer: ModelContainer
    private let weatherService: WeatherService
    private let locationService: LocationService
    private var hasAttemptedBackfill = false

    init(modelContainer: ModelContainer, weatherService: WeatherService, locationService: LocationService) {
        self.modelContainer = modelContainer
        self.weatherService = weatherService
        self.locationService = locationService
    }

    func runIfNeeded(limit: Int = 10, pageSize: Int = 5, maxScannedEpisodes: Int = 50) async {
        guard !hasAttemptedBackfill else {
            return
        }

        hasAttemptedBackfill = true

        let context = modelContainer.mainContext
        let pageSize = max(1, pageSize)
        let limit = max(0, limit)
        let maxScannedEpisodes = max(pageSize, maxScannedEpisodes)

        guard limit > 0, hasBackfillCandidates(in: context, pageSize: pageSize, maxScannedEpisodes: maxScannedEpisodes) else {
            return
        }

        let location: CLLocation
        do {
            location = try await locationService.requestApproximateLocation()
        } catch {
            return
        }

        var scannedEpisodes = 0
        var fetchOffset = 0
        var attemptedBackfills = 0

        while attemptedBackfills < limit, scannedEpisodes < maxScannedEpisodes {
            guard !Task.isCancelled else {
                return
            }

            let page = candidatePage(
                in: context,
                pageSize: min(pageSize, maxScannedEpisodes - scannedEpisodes),
                fetchOffset: fetchOffset
            )

            guard page.scannedCount > 0 else {
                break
            }

            scannedEpisodes += page.scannedCount
            fetchOffset += page.scannedCount

            for candidate in page.candidates {
                guard attemptedBackfills < limit, !Task.isCancelled else {
                    return
                }

                attemptedBackfills += 1

                do {
                    guard let snapshot = try await weatherService.fetchWeather(for: candidate.startedAt, location: location) else {
                        continue
                    }

                    guard
                        let episode = context.model(for: candidate.modelID) as? Episode,
                        episode.weatherSnapshot?.source.localizedCaseInsensitiveContains("legacy") == true
                    else {
                        continue
                    }

                    if let existing = episode.weatherSnapshot {
                        existing.recordedAt = snapshot.recordedAt
                        existing.temperature = snapshot.temperature
                        existing.condition = snapshot.condition
                        existing.humidity = snapshot.humidity
                        existing.pressure = snapshot.pressure
                        existing.precipitation = snapshot.precipitation
                        existing.weatherCode = snapshot.weatherCode
                        existing.source = snapshot.source
                    } else {
                        episode.weatherSnapshot = WeatherSnapshot(snapshot: snapshot, episode: episode)
                    }

                    episode.markUpdated()
                } catch {
                    continue
                }
            }

            if context.hasChanges {
                try? context.save()
            }

            await Task.yield()
        }
    }

    private func hasBackfillCandidates(in context: ModelContext, pageSize: Int, maxScannedEpisodes: Int) -> Bool {
        var scannedEpisodes = 0
        var fetchOffset = 0

        while scannedEpisodes < maxScannedEpisodes {
            let page = candidatePage(
                in: context,
                pageSize: min(pageSize, maxScannedEpisodes - scannedEpisodes),
                fetchOffset: fetchOffset
            )

            guard page.scannedCount > 0 else {
                return false
            }

            if !page.candidates.isEmpty {
                return true
            }

            scannedEpisodes += page.scannedCount
            fetchOffset += page.scannedCount
        }

        return false
    }

    private func candidatePage(in context: ModelContext, pageSize: Int, fetchOffset: Int) -> CandidatePage {
        var descriptor = FetchDescriptor<Episode>(sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)])
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = fetchOffset

        guard let episodes = try? context.fetch(descriptor) else {
            return CandidatePage(scannedCount: 0, candidates: [])
        }

        let candidates = episodes.compactMap { episode -> BackfillCandidate? in
            guard episode.weatherSnapshot?.source.localizedCaseInsensitiveContains("legacy") == true else {
                return nil
            }

            return BackfillCandidate(modelID: episode.persistentModelID, startedAt: episode.startedAt)
        }

        return CandidatePage(scannedCount: episodes.count, candidates: candidates)
    }
}
