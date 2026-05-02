import Testing
@testable import Symi

struct FeatureFlagsTests {
    @Test
    func monetizationIsDisabledByDefault() {
        let flags = FeatureFlags.defaults

        #expect(!flags.isEnabled(.monetization))
    }

    @Test
    func launchArgumentsCanEnableFeatureFlags() {
        let flags = FeatureFlags.resolved(
            arguments: ["-feature_monetization", "true"],
            environment: [:]
        )

        #expect(flags.isEnabled(.monetization))
    }

    @Test
    func launchArgumentsCanDisableFeatureFlags() {
        let flags = FeatureFlags.defaults
            .setting(.monetization, to: true)
        let resolvedFlags = FeatureFlags.resolved(
            arguments: ["-feature_monetization", "off"],
            environment: [:],
            base: flags
        )

        #expect(!resolvedFlags.isEnabled(.monetization))
    }

    @Test
    func environmentCanEnableFeatureFlags() {
        let flags = FeatureFlags.resolved(
            arguments: [],
            environment: ["SYMI_FEATURE_MONETIZATION": "1"]
        )

        #expect(flags.isEnabled(.monetization))
    }

    @Test
    func launchArgumentsTakePrecedenceOverEnvironment() {
        let flags = FeatureFlags.resolved(
            arguments: ["-feature_monetization", "false"],
            environment: ["SYMI_FEATURE_MONETIZATION": "true"]
        )

        #expect(!flags.isEnabled(.monetization))
    }

    @Test
    func appLaunchConfigurationResolvesFeatureFlags() {
        let configuration = AppLaunchConfiguration(
            arguments: ["-feature_monetization", "yes"],
            environment: [:]
        )

        #expect(configuration.featureFlags.isEnabled(.monetization))
    }

    @Test
    func symiPlusProductConfigurationParsesCommaSeparatedProductIDs() {
        let productIDs = SymiPlusProductConfiguration.productIDs(
            from: "eu.mpwg.MigraineTracker.symiPlus.monthly, eu.mpwg.MigraineTracker.symiPlus.yearly"
        )

        #expect(productIDs == [
            "eu.mpwg.MigraineTracker.symiPlus.monthly",
            "eu.mpwg.MigraineTracker.symiPlus.yearly"
        ])
    }

    @Test
    func symiPlusProductConfigurationFallsBackForMissingBuildSetting() {
        #expect(SymiPlusProductConfiguration.productIDs(from: nil) == [SymiPlusProductConfiguration.defaultProductID])
        #expect(SymiPlusProductConfiguration.productIDs(from: "$(SYMI_PLUS_PRODUCT_IDS)") == [SymiPlusProductConfiguration.defaultProductID])
    }
}
