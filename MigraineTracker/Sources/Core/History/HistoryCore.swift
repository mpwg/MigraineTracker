import Foundation
import Observation

struct EpisodeListItem: Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let type: EpisodeType
    let intensity: Int
    let medicationCount: Int
    let symptoms: [String]

    init(record: EpisodeRecord) {
        id = record.id
        startedAt = record.startedAt
        type = record.type
        intensity = record.intensity
        medicationCount = record.medications.count
        symptoms = record.symptoms
    }
}

struct HistoryDaySummary: Equatable {
    let date: Date
    let episodeCount: Int
    let highestIntensity: Int
}

struct HistoryMonthData: Equatable {
    let month: Date
    let episodesByDay: [Date: [EpisodeRecord]]
}

struct LoadHistoryMonthUseCase {
    let repository: EpisodeRepository

    func execute(month: Date) async throws -> HistoryMonthData {
        let repository = repository
        let records = try await Task.detached(priority: .userInitiated) {
            try repository.fetchByMonth(month)
        }.value
        return HistoryMonthData(
            month: month,
            episodesByDay: Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.startedAt) }
        )
    }
}

struct LoadDayEpisodesUseCase {
    let repository: EpisodeRepository

    func execute(day: Date) async throws -> [EpisodeRecord] {
        let repository = repository
        return try await Task.detached(priority: .userInitiated) {
            try repository.fetchByDay(day)
        }.value
    }
}

struct LoadEpisodeDetailUseCase {
    let repository: EpisodeRepository

    func execute(id: UUID) async throws -> EpisodeRecord? {
        let repository = repository
        return try await Task.detached(priority: .userInitiated) {
            try repository.load(id: id)
        }.value
    }
}

struct DeleteEpisodeUseCase {
    let repository: EpisodeRepository

    func execute(id: UUID) async throws {
        let repository = repository
        try await Task.detached(priority: .userInitiated) {
            try repository.softDelete(id: id)
        }.value
    }
}

@MainActor
@Observable
final class HistoryController {
    var selectedDay: Date
    var displayedMonth: Date
    var editingEpisodeID: UUID?
    var pendingDeletionID: UUID?
    var isPresentingNewEpisode = false
    var isPresentingSettings = false
    var errorMessage: String?
    private(set) var monthData: HistoryMonthData
    private(set) var selectedDayEpisodes: [EpisodeRecord] = []

    private let loadHistoryMonthUseCase: LoadHistoryMonthUseCase
    private let loadDayEpisodesUseCase: LoadDayEpisodesUseCase
    private let deleteEpisodeUseCase: DeleteEpisodeUseCase

    init(repository: EpisodeRepository, initialDay: Date = .now) {
        let calendar = Calendar.current
        self.selectedDay = initialDay
        self.displayedMonth = calendar.startOfMonth(for: initialDay)
        self.loadHistoryMonthUseCase = LoadHistoryMonthUseCase(repository: repository)
        self.loadDayEpisodesUseCase = LoadDayEpisodesUseCase(repository: repository)
        self.deleteEpisodeUseCase = DeleteEpisodeUseCase(repository: repository)
        self.monthData = HistoryMonthData(month: calendar.startOfMonth(for: initialDay), episodesByDay: [:])
        Task { await reloadAll() }
    }

    var episodesByDay: [Date: [EpisodeRecord]] {
        monthData.episodesByDay
    }

    var daySummary: HistoryDaySummary {
        let episodes = selectedDayEpisodes
        return HistoryDaySummary(
            date: selectedDay,
            episodeCount: episodes.count,
            highestIntensity: episodes.map(\.intensity).max() ?? 0
        )
    }

    func reloadAll() async {
        do {
            try await reloadMonthData()
            try await reloadSelectedDayEpisodes()
            errorMessage = nil
        } catch {
            errorMessage = "Tagebuch konnte nicht geladen werden."
        }
    }

    func reloadMonthData() async throws {
        monthData = try await loadHistoryMonthUseCase.execute(month: displayedMonth)
    }

    func reloadSelectedDayEpisodes() async throws {
        selectedDayEpisodes = try await loadDayEpisodesUseCase.execute(day: selectedDay)
        syncSelectedDayIntoMonthData()
    }

    func goToPreviousMonth() {
        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        Task {
        do {
            try await reloadMonthData()
            errorMessage = nil
        } catch {
            errorMessage = "Tagebuch konnte nicht geladen werden."
        }
        }
    }

    func goToNextMonth() {
        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        Task {
        do {
            try await reloadMonthData()
            errorMessage = nil
        } catch {
            errorMessage = "Tagebuch konnte nicht geladen werden."
        }
        }
    }

    func selectDay(_ day: Date) {
        selectedDay = day
        let month = Calendar.current.startOfMonth(for: day)
        let didChangeMonth = !Calendar.current.isDate(month, equalTo: displayedMonth, toGranularity: .month)
        if didChangeMonth {
            displayedMonth = month
        }

        Task {
        do {
            if didChangeMonth {
                try await reloadMonthData()
            }
            try await reloadSelectedDayEpisodes()
            errorMessage = nil
        } catch {
            errorMessage = "Tagebuch konnte nicht geladen werden."
        }
        }
    }

    func deletePendingEpisode() {
        guard let pendingDeletionID else {
            return
        }

        Task {
        do {
            try await deleteEpisodeUseCase.execute(id: pendingDeletionID)
            self.pendingDeletionID = nil
            try await reloadSelectedDayEpisodes()
            errorMessage = nil
        } catch {
            errorMessage = "Löschen fehlgeschlagen."
        }
        }
    }

    func handleSavedEpisode() {
        Task {
        do {
            try await reloadMonthData()
            try await reloadSelectedDayEpisodes()
            errorMessage = nil
        } catch {
            errorMessage = "Tagebuch konnte nicht geladen werden."
        }
        }
    }

    func defaultStartDateForSelectedDay() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let day = calendar.startOfDay(for: selectedDay)

        if day == today {
            return .now
        }

        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private func syncSelectedDayIntoMonthData() {
        let selectedMonth = Calendar.current.startOfMonth(for: selectedDay)
        guard Calendar.current.isDate(selectedMonth, equalTo: displayedMonth, toGranularity: .month) else {
            return
        }

        var updated = monthData.episodesByDay
        let day = Calendar.current.startOfDay(for: selectedDay)
        if selectedDayEpisodes.isEmpty {
            updated.removeValue(forKey: day)
        } else {
            updated[day] = selectedDayEpisodes
        }
        monthData = HistoryMonthData(month: monthData.month, episodesByDay: updated)
    }
}
