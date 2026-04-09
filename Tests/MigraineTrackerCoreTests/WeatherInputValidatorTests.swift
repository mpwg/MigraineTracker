import Testing
@testable import MigraineTrackerCore

struct WeatherInputValidatorTests {
    @Test
    func disabledWeatherReturnsNil() throws {
        let result = try WeatherInputValidator.validate(
            isEnabled: false,
            condition: "Sonnig",
            temperatureText: "20",
            humidityText: "55",
            pressureText: "1013",
            source: "Manuell"
        )

        #expect(result == nil)
    }

    @Test
    func emptyEnabledWeatherReturnsNil() throws {
        let result = try WeatherInputValidator.validate(
            isEnabled: true,
            condition: " ",
            temperatureText: "",
            humidityText: "",
            pressureText: "",
            source: ""
        )

        #expect(result == nil)
    }

    @Test
    func validWeatherUsesCommaNumbersAndDefaultSource() throws {
        let result = try WeatherInputValidator.validate(
            isEnabled: true,
            condition: "Regen",
            temperatureText: "18,5",
            humidityText: "72",
            pressureText: "1004",
            source: ""
        )

        #expect(
            result == ValidatedWeatherSnapshot(
                condition: "Regen",
                temperature: 18.5,
                humidity: 72,
                pressure: 1004,
                source: "Manuell"
            )
        )
    }

    @Test
    func invalidTemperatureTextThrows() {
        #expect(throws: WeatherValidationError.invalidNumber("Temperatur")) {
            try WeatherInputValidator.validate(
                isEnabled: true,
                condition: "",
                temperatureText: "warm",
                humidityText: "",
                pressureText: "",
                source: ""
            )
        }
    }

    @Test
    func outOfRangeHumidityThrows() {
        #expect(throws: WeatherValidationError.valueOutOfRange(fieldName: "Luftfeuchte", expectedRange: "0 bis 100 %")) {
            try WeatherInputValidator.validate(
                isEnabled: true,
                condition: "",
                temperatureText: "",
                humidityText: "140",
                pressureText: "",
                source: ""
            )
        }
    }
}
