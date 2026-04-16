import CoreLocation
import Foundation
import OpenMeteoSdk
import SwiftData

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
    static let providerName = "Open-Meteo"
    static let providerURL = URL(string: "https://open-meteo.com/")!
    static let licenceName = "CC BY 4.0"
    static let licenceURL = URL(string: "https://creativecommons.org/licenses/by/4.0/")!
    static let sourceDescription = "Wetterdaten von Open-Meteo, basierend auf DWD ICON."
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

    var errorDescription: String? {
        switch self {
        case .noHourlyData:
            "Die Wetterquelle hat keine stündlichen Daten geliefert."
        case .noMatchingHour:
            "Für den Episodenzeitpunkt wurde kein passender Wetterwert gefunden."
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

struct OpenMeteoDwdWeatherService: WeatherService {
    func fetchWeather(for date: Date, location: CLLocation) async throws -> WeatherSnapshotData? {
        if date > .now {
            throw EpisodeSaveError.futureDate
        }

        let endpoint = endpointURL(for: date)
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,relative_humidity_2m,surface_pressure,precipitation,weather_code"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "format", value: "flatbuffers"),
            URLQueryItem(name: "start_date", value: isoDayString(for: date)),
            URLQueryItem(name: "end_date", value: isoDayString(for: date)),
            URLQueryItem(name: "past_days", value: "0"),
            URLQueryItem(name: "models", value: isHistorical(date) ? "icon_seamless" : nil),
        ].compactMap { item in
            guard let value = item.value else {
                return nil
            }
            return URLQueryItem(name: item.name, value: value)
        }

        guard let url = components?.url else {
            return nil
        }

        let responses = try await WeatherApiResponse.fetch(url: url)
        guard let response = responses.first, let hourly = response.hourly else {
            throw WeatherServiceError.noHourlyData
        }

        let timestamps = hourly.getDateTime(offset: response.utcOffsetSeconds)
        guard let matchedIndex = timestamps.enumerated().min(by: {
            abs($0.element.timeIntervalSince(date)) < abs($1.element.timeIntervalSince(date))
        })?.offset else {
            throw WeatherServiceError.noMatchingHour
        }

        let temperature = value(at: matchedIndex, from: hourly, variableIndex: 0)
        let humidity = value(at: matchedIndex, from: hourly, variableIndex: 1)
        let pressure = value(at: matchedIndex, from: hourly, variableIndex: 2)
        let precipitation = value(at: matchedIndex, from: hourly, variableIndex: 3)
        let weatherCodeValue = value(at: matchedIndex, from: hourly, variableIndex: 4)
        let weatherCode = weatherCodeValue.map { Int($0.rounded()) }

        return WeatherSnapshotData(
            recordedAt: timestamps[matchedIndex],
            condition: WeatherCodeMapper.description(for: weatherCode),
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            precipitation: precipitation,
            weatherCode: weatherCode,
            source: isHistorical(date) ? "Open-Meteo DWD ICON Archiv" : "Open-Meteo DWD ICON"
        )
    }

    private func endpointURL(for date: Date) -> URL {
        if isHistorical(date) {
            return URL(string: "https://historical-forecast-api.open-meteo.com/v1/forecast")!
        }

        return URL(string: "https://api.open-meteo.com/v1/dwd-icon")!
    }

    private func isHistorical(_ date: Date) -> Bool {
        !Calendar.current.isDate(date, inSameDayAs: .now)
    }

    private func isoDayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func value(at offset: Int, from hourly: openmeteo_sdk_VariablesWithTime, variableIndex: Int) -> Double? {
        guard let values = hourly.variables(at: Int32(variableIndex))?.values, values.indices.contains(offset) else {
            return nil
        }

        return Double(values[offset])
    }
}

enum WeatherCodeMapper {
    static func description(for code: Int?) -> String {
        guard let code else {
            return "Nicht verfügbar"
        }

        switch code {
        case 0:
            return "Klar"
        case 1:
            return "Überwiegend klar"
        case 2:
            return "Teilweise bewölkt"
        case 3:
            return "Bedeckt"
        case 45, 48:
            return "Nebelig"
        case 51, 53, 55:
            return "Nieselregen"
        case 56, 57:
            return "Gefrierender Nieselregen"
        case 61, 63, 65:
            return "Regen"
        case 66, 67:
            return "Gefrierender Regen"
        case 71, 73, 75, 77:
            return "Schnee"
        case 80, 81, 82:
            return "Regenschauer"
        case 85, 86:
            return "Schneeschauer"
        case 95:
            return "Gewitter"
        case 96, 99:
            return "Gewitter mit Hagel"
        default:
            return "Unbekannt"
        }
    }
}

@MainActor
final class WeatherBackfillService {
    private let modelContainer: ModelContainer
    private let weatherService: WeatherService
    private let locationService: LocationService
    private var hasAttemptedBackfill = false

    init(modelContainer: ModelContainer, weatherService: WeatherService, locationService: LocationService) {
        self.modelContainer = modelContainer
        self.weatherService = weatherService
        self.locationService = locationService
    }

    func runIfNeeded(limit: Int = 10) async {
        guard !hasAttemptedBackfill else {
            return
        }

        hasAttemptedBackfill = true

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Episode>(sortBy: [SortDescriptor(\Episode.startedAt, order: .reverse)])
        guard
            let episodes = try? context.fetch(descriptor).filter({ $0.weatherSnapshot?.source.localizedCaseInsensitiveContains("legacy") == true }),
            !episodes.isEmpty
        else {
            return
        }

        let location: CLLocation
        do {
            location = try await locationService.requestApproximateLocation()
        } catch {
            return
        }

        for episode in episodes.prefix(limit) {
            do {
                guard let snapshot = try await weatherService.fetchWeather(for: episode.startedAt, location: location) else {
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

        try? context.save()
    }
}
