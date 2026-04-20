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

    func execute(month: Date) throws -> HistoryMonthData {
        let records = try repository.fetchByMonth(month)
        return HistoryMonthData(
            month: month,
            episodesByDay: Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.startedAt) }
        )
    }
}

struct LoadDayEpisodesUseCase {
    let repository: EpisodeRepository

    func execute(day: Date) throws -> [EpisodeRecord] {
        try repository.fetchByDay(day)
    }
}

struct LoadEpisodeDetailUseCase {
    let repository: EpisodeRepository

    func execute(id: UUID) throws -> EpisodeRecord? {
        try repository.load(id: id)
    }
}

struct DeleteEpisodeUseCase {
    let repository: EpisodeRepository

    func execute(id: UUID) throws {
        try repository.softDelete(id: id)
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
        reload()
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

    func reload() {
        do {
            monthData = try loadHistoryMonthUseCase.execute(month: displayedMonth)
            selectedDayEpisodes = try loadDayEpisodesUseCase.execute(day: selectedDay)
            errorMessage = nil
        } catch {
            errorMessage = "Tagebuch konnte nicht geladen werden."
        }
    }

    func goToPreviousMonth() {
        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        reload()
    }

    func goToNextMonth() {
        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        reload()
    }

    func selectDay(_ day: Date) {
        selectedDay = day
        let month = Calendar.current.startOfMonth(for: day)
        if !Calendar.current.isDate(month, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = month
        }
        reload()
    }

    func deletePendingEpisode() {
        guard let pendingDeletionID else {
            return
        }

        do {
            try deleteEpisodeUseCase.execute(id: pendingDeletionID)
            self.pendingDeletionID = nil
            reload()
        } catch {
            errorMessage = "Löschen fehlgeschlagen."
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
}
