import Foundation

#if canImport(UIKit)
import UIKit
#endif

protocol DeviceIdentityProviding {
    func currentDeviceID() -> String
}

struct SystemDeviceIdentityProvider: DeviceIdentityProviding {
    private let defaults: UserDefaults
    private let storageKey = "eu.mpwg.MigraineTracker.device-id"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentDeviceID() -> String {
        #if canImport(UIKit)
        if let identifier = UIDevice.current.identifierForVendor?.uuidString {
            return identifier
        }
        #endif

        if let persisted = defaults.string(forKey: storageKey), !persisted.isEmpty {
            return persisted
        }

        let generated = UUID().uuidString
        defaults.set(generated, forKey: storageKey)
        return generated
    }
}

enum PlatformSettingsLink {
    static var appSettingsURL: URL? {
        #if canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}
