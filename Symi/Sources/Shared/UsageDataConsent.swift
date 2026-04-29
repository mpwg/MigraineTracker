import Foundation
import Observation
import OSLog

enum UsageDataConsent: Equatable {
    case undecided
    case allowed
    case denied
}

protocol UsageDataConsentService: AnyObject {
    var usageDataConsent: UsageDataConsent { get }

    func setUsageDataCollectionAllowed(_ allowed: Bool)
}

final class UsageDataConsentStore {
    private let defaults: UserDefaults
    private let consentKey = "usageDataCollectionAllowed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var consent: UsageDataConsent {
        guard defaults.object(forKey: consentKey) != nil else {
            return .undecided
        }

        return defaults.bool(forKey: consentKey) ? .allowed : .denied
    }

    func setConsent(_ consent: UsageDataConsent) {
        switch consent {
        case .undecided:
            defaults.removeObject(forKey: consentKey)
        case .allowed:
            defaults.set(true, forKey: consentKey)
        case .denied:
            defaults.set(false, forKey: consentKey)
        }
    }
}

@MainActor
@Observable
final class AppTelemetryService: UsageDataConsentService {
    static let shared = AppTelemetryService()

    private static let logger = Logger(subsystem: "Symi", category: "Telemetry")
    private let store: UsageDataConsentStore
    private var launchConfiguration: AppLaunchConfiguration?
    private var isSentryStarted = false
    private var isTelemetryDeckStarted = false

    init(store: UsageDataConsentStore = UsageDataConsentStore()) {
        self.store = store
    }

    var usageDataConsent: UsageDataConsent {
        store.consent
    }

    var isUsageDataCollectionAllowed: Bool {
        usageDataConsent == .allowed
    }

    var shouldAskForUsageDataConsent: Bool {
        usageDataConsent == .undecided
    }

    func configureIfPermitted(launchConfiguration: AppLaunchConfiguration) {
        self.launchConfiguration = launchConfiguration
        guard usageDataConsent == .allowed else {
            stopTelemetry()
            return
        }

        startTelemetry(launchConfiguration: launchConfiguration)
    }

    func setUsageDataCollectionAllowed(_ allowed: Bool) {
        store.setConsent(allowed ? .allowed : .denied)

        if allowed, let launchConfiguration {
            startTelemetry(launchConfiguration: launchConfiguration)
        } else {
            stopTelemetry()
        }
    }

    private func startTelemetry(launchConfiguration: AppLaunchConfiguration) {
        guard !launchConfiguration.isScreenshotMode, !launchConfiguration.isRunningTests else {
            return
        }

        if !isSentryStarted, let sentryDSN = Self.sentryDSN {
            AppTelemetryGateway.startSentry(dsn: sentryDSN)
            AppSentryLogReporter.shared.setEnabled(true)
            isSentryStarted = true
        } else if Self.sentryDSN == nil {
            Self.logger.notice("Sentry ist deaktiviert, weil keine gültige DSN in der App-Konfiguration gefunden wurde.")
        }

        if !isTelemetryDeckStarted, let telemetryAppID = Self.telemetryAppID {
            AppTelemetryGateway.startTelemetryDeck(appID: telemetryAppID)
            isTelemetryDeckStarted = true
        }
    }

    private func stopTelemetry() {
        if isSentryStarted {
            AppSentryLogReporter.shared.setEnabled(false)
            AppTelemetryGateway.stopSentry()
            isSentryStarted = false
        }

        if isTelemetryDeckStarted {
            AppTelemetryGateway.stopTelemetryDeck()
            isTelemetryDeckStarted = false
        }
    }

    private static var sentryDSN: String? {
        normalize(Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String)
    }

    private static var telemetryAppID: String? {
        normalize(Bundle.main.object(forInfoDictionaryKey: "TELEMETRY_APP_ID") as? String)
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        if trimmed.hasPrefix("$("), trimmed.hasSuffix(")") {
            return nil
        }

        return trimmed
    }
}
