import Foundation
import SwiftUI

struct SectionAvailability: Equatable {
    let iOS: Bool
    let macOS: Bool
    let unavailableReason: String?

    init(iOS: Bool = true, macOS: Bool = true, unavailableReason: String? = nil) {
        self.iOS = iOS
        self.macOS = macOS
        self.unavailableReason = unavailableReason
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case capture
    case history
    case syncAndExport
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Heute"
        case .capture:
            "Erfassen"
        case .history:
            "Verlauf"
        case .syncAndExport:
            "Sync & Export"
        case .settings:
            "Einstellungen"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .capture:
            "plus.circle"
        case .history:
            "calendar"
        case .syncAndExport:
            "arrow.trianglehead.2.clockwise.icloud"
        case .settings:
            "gearshape"
        }
    }

    var availability: SectionAvailability {
        SectionAvailability()
    }

    static let macOSDefaultSection: AppSection = .history
    static let iOSDefaultTab: AppTab = .history
}
