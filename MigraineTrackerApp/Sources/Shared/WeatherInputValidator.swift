import Foundation

struct ValidatedWeatherSnapshot: Equatable {
    let condition: String
    let temperature: Double?
    let humidity: Double?
    let pressure: Double?
    let source: String
}

enum WeatherValidationError: LocalizedError, Equatable {
    case invalidNumber(String)
    case valueOutOfRange(fieldName: String, expectedRange: String)

    var errorDescription: String? {
        switch self {
        case let .invalidNumber(fieldName):
            "\(fieldName) muss eine gültige Zahl sein."
        case let .valueOutOfRange(fieldName, expectedRange):
            "\(fieldName) muss im Bereich \(expectedRange) liegen."
        }
    }
}

enum WeatherInputValidator {
    static func validate(
        isEnabled: Bool,
        condition: String,
        temperatureText: String,
        humidityText: String,
        pressureText: String,
        source: String
    ) throws -> ValidatedWeatherSnapshot? {
        guard isEnabled else {
            return nil
        }

        let trimmedCondition = condition.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemperature = temperatureText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHumidity = humidityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPressure = pressureText.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasAnyInput = !trimmedCondition.isEmpty
            || !trimmedSource.isEmpty
            || !trimmedTemperature.isEmpty
            || !trimmedHumidity.isEmpty
            || !trimmedPressure.isEmpty

        guard hasAnyInput else {
            return nil
        }

        let temperature = try parseOptionalNumber(from: trimmedTemperature, fieldName: "Temperatur")
        let humidity = try parseOptionalNumber(from: trimmedHumidity, fieldName: "Luftfeuchte")
        let pressure = try parseOptionalNumber(from: trimmedPressure, fieldName: "Luftdruck")

        if let temperature, !(-50 ... 60).contains(temperature) {
            throw WeatherValidationError.valueOutOfRange(
                fieldName: "Temperatur",
                expectedRange: "-50 bis 60 °C"
            )
        }

        if let humidity, !(0 ... 100).contains(humidity) {
            throw WeatherValidationError.valueOutOfRange(
                fieldName: "Luftfeuchte",
                expectedRange: "0 bis 100 %"
            )
        }

        if let pressure, !(870 ... 1085).contains(pressure) {
            throw WeatherValidationError.valueOutOfRange(
                fieldName: "Luftdruck",
                expectedRange: "870 bis 1085 hPa"
            )
        }

        return ValidatedWeatherSnapshot(
            condition: trimmedCondition,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            source: trimmedSource.isEmpty ? "Manuell" : trimmedSource
        )
    }

    private static func parseOptionalNumber(from text: String, fieldName: String) throws -> Double? {
        guard !text.isEmpty else {
            return nil
        }

        let normalized = text.replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized) else {
            throw WeatherValidationError.invalidNumber(fieldName)
        }

        return value
    }
}
