import Foundation

@MainActor
final class SyncServiceAdapter: SyncService {
    private let coordinator: SyncCoordinator

    init(coordinator: SyncCoordinator) {
        self.coordinator = coordinator
    }

    var isEnabled: Bool { coordinator.isEnabled }
    var status: SyncStatusSnapshot { coordinator.status }
    var conflicts: [SyncConflict] { coordinator.conflicts }

    func setSyncEnabled(_ enabled: Bool) {
        coordinator.setSyncEnabled(enabled)
    }

    func refreshStatus() {
        coordinator.refreshStatus()
    }

    func syncNow() async {
        await coordinator.syncNow()
    }

    func retryLastError() async {
        await coordinator.retryLastError()
    }

    func resolveConflictKeepingLocal(_ conflict: SyncConflict) async {
        await coordinator.resolveConflictKeepingLocal(conflict)
    }

    func resolveConflictUsingRemote(_ conflict: SyncConflict) async {
        await coordinator.resolveConflictUsingRemote(conflict)
    }
}

extension AppLogStore: AppLogService {}
