import Foundation
import Observation

struct TherapyMedicationItem: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let name: String
    nonisolated let dosage: String
    nonisolated let frequency: String
    nonisolated let timeText: String
    nonisolated let isActive: Bool
    nonisolated let startDate: Date
    nonisolated let endDate: Date?

    nonisolated init(record: ContinuousMedicationRecord) {
        id = record.id
        name = record.name
        dosage = record.dosage.isEmpty ? "Dosierung nicht angegeben" : record.dosage
        frequency = record.frequency
        timeText = Self.timeText(from: record.frequency)
        isActive = record.isActive
        startDate = record.startDate
        endDate = record.endDate
    }

    private nonisolated static func timeText(from frequency: String) -> String {
        let pattern = #"\b\d{1,2}:\d{2}\b"#
        guard let range = frequency.range(of: pattern, options: .regularExpression) else {
            return "Heute"
        }

        return String(frequency[range])
    }
}

struct LoadTherapyUseCase {
    let repository: ContinuousMedicationRepository

    func execute() async throws -> [ContinuousMedicationRecord] {
        let repository = repository
        return try await Task.detached(priority: .userInitiated) {
            try repository.fetchAll()
        }.value
    }
}

@MainActor
@Observable
final class TherapyViewModel {
    private(set) var medications: [ContinuousMedicationRecord] = []
    var medicationEditor: ContinuousMedicationDraft?
    var message: String?

    private let repository: ContinuousMedicationRepository
    private let loadTherapyUseCase: LoadTherapyUseCase
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(repository: ContinuousMedicationRepository) {
        self.repository = repository
        self.loadTherapyUseCase = LoadTherapyUseCase(repository: repository)
    }

    var todayMedications: [TherapyMedicationItem] {
        medications
            .filter { $0.kind == .therapy && $0.isActive }
            .map(TherapyMedicationItem.init(record:))
    }

    var currentMeasures: [ContinuousMedicationRecord] {
        medications.filter { $0.status == .active && $0.isCurrentOnDate(.now) }
    }

    var historicalMeasures: [ContinuousMedicationRecord] {
        medications.filter { $0.status != .active || !$0.isCurrentOnDate(.now) }
    }

    func measures(kind: TherapyMeasureKind, status: TherapyMeasureStatus? = nil) -> [ContinuousMedicationRecord] {
        medications.filter { medication in
            medication.kind == kind && (status.map { medication.status == $0 } ?? true)
        }
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await loadTherapyUseCase.execute()
                guard !Task.isCancelled else { return }
                medications = loaded
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                message = "Therapie konnte nicht geladen werden."
            }
        }
    }

    func presentMedicationEditor(for medication: ContinuousMedicationRecord?, kind: TherapyMeasureKind = .therapy) {
        medicationEditor = medication.map(ContinuousMedicationDraft.init(record:)) ?? ContinuousMedicationDraft(kind: kind)
        message = nil
    }

    func saveMedication(_ draft: ContinuousMedicationDraft) async {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            message = "Bitte gib ein Medikament an."
            return
        }

        let repository = repository
        var normalizedDraft = draft
        normalizedDraft.name = trimmedName
        if normalizedDraft.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedDraft.category = normalizedDraft.kind.defaultCategory
        }

        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try repository.save(normalizedDraft)
            }.value
            medicationEditor = nil
            message = nil
            load()
        } catch {
            message = "Medikationsplan konnte nicht gespeichert werden."
        }
    }

    func updateStatus(id: UUID, status: TherapyMeasureStatus) {
        let repository = repository
        Task { [weak self] in
            guard let self else { return }
            guard let medication = medications.first(where: { $0.id == id }) else { return }
            var draft = ContinuousMedicationDraft(record: medication)
            draft.status = status
            if status == .ended, draft.endDate == nil {
                draft.endDate = .now
            }

            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try repository.save(draft)
                }.value
                load()
            } catch {
                message = "Eintrag konnte nicht aktualisiert werden."
            }
        }
    }

    func deleteMeasure(id: UUID) {
        let repository = repository
        Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.detached(priority: .userInitiated) {
                    try repository.delete(id: id)
                }.value
                load()
            } catch {
                message = "Eintrag konnte nicht gelöscht werden."
            }
        }
    }
}
