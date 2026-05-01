import Foundation
import SwiftUI

nonisolated enum FeatureFlag: String, CaseIterable, Sendable {
    case monetization

    var defaultValue: Bool {
        switch self {
        case .monetization:
            false
        }
    }

    var launchArgumentName: String {
        "-feature_\(rawValue)"
    }

    var environmentName: String {
        "SYMI_FEATURE_\(rawValue.uppercased())"
    }
}

nonisolated struct FeatureFlags: Equatable, Sendable {
    private var values: [FeatureFlag: Bool]

    init(values: [FeatureFlag: Bool] = [:]) {
        self.values = values
    }

    static let defaults = FeatureFlags()

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        values[flag] ?? flag.defaultValue
    }

    func setting(_ flag: FeatureFlag, to isEnabled: Bool) -> FeatureFlags {
        var copy = self
        copy.values[flag] = isEnabled
        return copy
    }

    static func resolved(
        arguments: [String],
        environment: [String: String],
        base: FeatureFlags = .defaults
    ) -> FeatureFlags {
        FeatureFlag.allCases.reduce(base) { flags, flag in
            if let value = boolValue(for: flag.launchArgumentName, in: arguments) {
                return flags.setting(flag, to: value)
            }

            if let rawValue = environment[flag.environmentName], let value = boolValue(from: rawValue) {
                return flags.setting(flag, to: value)
            }

            return flags
        }
    }

    private static func boolValue(for key: String, in arguments: [String]) -> Bool? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }

        return boolValue(from: arguments[index + 1])
    }

    private static func boolValue(from rawValue: String) -> Bool? {
        switch rawValue.lowercased() {
        case "1", "true", "yes", "on":
            true
        case "0", "false", "no", "off":
            false
        default:
            nil
        }
    }
}

private struct FeatureFlagsEnvironmentKey: EnvironmentKey {
    static let defaultValue = FeatureFlags.defaults
}

extension EnvironmentValues {
    var featureFlags: FeatureFlags {
        get { self[FeatureFlagsEnvironmentKey.self] }
        set { self[FeatureFlagsEnvironmentKey.self] = newValue }
    }
}
