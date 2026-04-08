import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case capture
    case history
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Heute"
        case .capture:
            "Erfassen"
        case .history:
            "Verlauf"
        case .export:
            "Export"
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
        case .export:
            "square.and.arrow.up"
        }
    }
}
