import Foundation
import Observation

enum DoctorSource: String, CaseIterable, Codable, Identifiable {
    case manual = "Manuell"
    case oegkDirectory = "ÖGK-Suchkatalog"

    nonisolated var id: String { rawValue }
}

enum AppointmentReminderStatus: String, CaseIterable, Codable, Identifiable {
    case notRequested = "Nicht angefragt"
    case authorized = "Erlaubt"
    case denied = "Abgelehnt"
    case scheduled = "Geplant"
    case failed = "Fehlgeschlagen"

    nonisolated var id: String { rawValue }
}

struct DoctorRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let createdAt: Date
    nonisolated let updatedAt: Date
    nonisolated let deletedAt: Date?
    nonisolated let name: String
    nonisolated let specialty: String
    nonisolated let street: String
    nonisolated let city: String
    nonisolated let state: String
    nonisolated let postalCode: String?
    nonisolated let phone: String
    nonisolated let email: String
    nonisolated let notes: String
    nonisolated let source: DoctorSource
    nonisolated let appointments: [AppointmentRecord]

    nonisolated var isDeleted: Bool {
        deletedAt != nil
    }

    nonisolated var addressLine: String {
        [street, [postalCode, city].compactMap { $0 }.joined(separator: " "), state]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
    }
}

struct DoctorDirectoryRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: String
    nonisolated let name: String
    nonisolated let specialty: String
    nonisolated let street: String
    nonisolated let city: String
    nonisolated let state: String
    nonisolated let postalCode: String?
    nonisolated let sourceLabel: String
    nonisolated let sourceURL: String

    nonisolated var addressLine: String {
        [street, [postalCode, city].compactMap { $0 }.joined(separator: " "), state]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
    }

    nonisolated var postalCodeSortKey: String {
        postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "9999"
    }
}

struct DoctorDirectorySection: Identifiable, Equatable, Sendable {
    nonisolated let title: String
    nonisolated let entries: [DoctorDirectoryRecord]

    nonisolated var id: String { title }
}

struct UpcomingAppointmentListItem: Identifiable, Equatable, Sendable {
    nonisolated let appointment: AppointmentRecord
    nonisolated let doctor: DoctorRecord

    nonisolated var id: UUID { appointment.id }
}

struct AppointmentRecord: Identifiable, Equatable, Sendable {
    nonisolated let id: UUID
    nonisolated let doctorID: UUID?
    nonisolated let createdAt: Date
    nonisolated let updatedAt: Date
    nonisolated let deletedAt: Date?
    nonisolated let scheduledAt: Date
    nonisolated let endsAt: Date?
    nonisolated let practiceName: String
    nonisolated let addressText: String
    nonisolated let note: String
    nonisolated let reminderEnabled: Bool
    nonisolated let reminderLeadTimeMinutes: Int
    nonisolated let reminderStatus: AppointmentReminderStatus
    nonisolated let notificationRequestID: String?

    nonisolated var isDeleted: Bool {
        deletedAt != nil
    }
}

struct DoctorDraft: Equatable, Sendable {
    nonisolated var id: UUID?
    nonisolated var name: String
    nonisolated var specialty: String
    nonisolated var street: String
    nonisolated var city: String
    nonisolated var state: String
    nonisolated var postalCode: String
    nonisolated var phone: String
    nonisolated var email: String
    nonisolated var notes: String
    nonisolated var source: DoctorSource

    nonisolated static func makeNew() -> DoctorDraft {
        DoctorDraft(
            id: nil,
            name: "",
            specialty: "",
            street: "",
            city: "",
            state: "",
            postalCode: "",
            phone: "",
            email: "",
            notes: "",
            source: .manual
        )
    }

    nonisolated static func from(record: DoctorRecord) -> DoctorDraft {
        DoctorDraft(
            id: record.id,
            name: record.name,
            specialty: record.specialty,
            street: record.street,
            city: record.city,
            state: record.state,
            postalCode: record.postalCode ?? "",
            phone: record.phone,
            email: record.email,
            notes: record.notes,
            source: record.source
        )
    }

    nonisolated mutating func applyDirectoryEntry(_ entry: DoctorDirectoryRecord) {
        name = entry.name
        specialty = entry.specialty
        street = entry.street
        city = entry.city
        state = entry.state
        postalCode = entry.postalCode ?? ""
        source = .oegkDirectory
    }
}

struct AppointmentDraft: Equatable, Sendable {
    nonisolated var id: UUID?
    nonisolated var doctorID: UUID
    nonisolated var scheduledAt: Date
    nonisolated var endsAtEnabled: Bool
    nonisolated var endsAt: Date
    nonisolated var practiceName: String
    nonisolated var addressText: String
    nonisolated var note: String
    nonisolated var reminderEnabled: Bool
    nonisolated var reminderLeadTimeMinutes: Int

    nonisolated static func makeNew(doctor: DoctorRecord) -> AppointmentDraft {
        let scheduledAt = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return AppointmentDraft(
            id: nil,
            doctorID: doctor.id,
            scheduledAt: scheduledAt,
            endsAtEnabled: false,
            endsAt: scheduledAt,
            practiceName: doctor.name,
            addressText: doctor.addressLine,
            note: "",
            reminderEnabled: true,
            reminderLeadTimeMinutes: 24 * 60
        )
    }

    nonisolated static func from(record: AppointmentRecord) -> AppointmentDraft {
        AppointmentDraft(
            id: record.id,
            doctorID: record.doctorID ?? UUID(),
            scheduledAt: record.scheduledAt,
            endsAtEnabled: record.endsAt != nil,
            endsAt: record.endsAt ?? record.scheduledAt,
            practiceName: record.practiceName,
            addressText: record.addressText,
            note: record.note,
            reminderEnabled: record.reminderEnabled,
            reminderLeadTimeMinutes: record.reminderLeadTimeMinutes
        )
    }
}

struct ReminderSchedulingResult: Equatable, Sendable {
    nonisolated let status: AppointmentReminderStatus
    nonisolated let requestID: String?
}

protocol DoctorRepository: Sendable {
    nonisolated func fetchAll() throws -> [DoctorRecord]
    nonisolated func load(id: UUID) throws -> DoctorRecord?
    @discardableResult
    nonisolated func save(draft: DoctorDraft) throws -> UUID
    nonisolated func softDelete(id: UUID) throws
}

protocol DoctorDirectoryRepository: Sendable {
    nonisolated func fetchEntries(searchText: String?) throws -> [DoctorDirectoryRecord]
    nonisolated func sourceAttribution() -> (label: String, url: String)
}

protocol AppointmentRepository: Sendable {
    nonisolated func fetchUpcoming(limit: Int?) throws -> [AppointmentRecord]
    nonisolated func fetchUpcoming(for doctorID: UUID) throws -> [AppointmentRecord]
    nonisolated func load(id: UUID) throws -> AppointmentRecord?
    @discardableResult
    nonisolated func save(draft: AppointmentDraft) throws -> UUID
    nonisolated func updateReminder(id: UUID, status: AppointmentReminderStatus, requestID: String?) throws
    nonisolated func softDelete(id: UUID) throws
}

protocol NotificationService {
    func scheduleAppointmentReminder(for appointment: AppointmentRecord, doctor: DoctorRecord) async -> ReminderSchedulingResult
    func removePendingNotification(requestID: String) async
}

enum DoctorSaveError: LocalizedError {
    case missingName

    var errorDescription: String? {
        switch self {
        case .missingName:
            "Bitte gib einen Namen an."
        }
    }
}

enum AppointmentSaveError: LocalizedError {
    case missingDoctor
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .missingDoctor:
            "Der Termin braucht eine Ärztin oder einen Arzt."
        case .invalidDateRange:
            "Die Endzeit darf nicht vor dem Beginn liegen."
        }
    }
}

struct SaveDoctorUseCase {
    let repository: DoctorRepository

    @discardableResult
    func execute(_ draft: DoctorDraft) async throws -> UUID {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DoctorSaveError.missingName
        }

        let repository = repository
        return try await Task.detached(priority: .userInitiated) {
            try repository.save(draft: draft)
        }.value
    }
}

struct SaveAppointmentUseCase {
    let appointmentRepository: AppointmentRepository
    let doctorRepository: DoctorRepository
    let notificationService: NotificationService

    @discardableResult
    func execute(_ draft: AppointmentDraft) async throws -> UUID {
        let doctorRepository = doctorRepository
        let appointmentRepository = appointmentRepository
        let doctor = try await Task.detached(priority: .userInitiated) {
            try doctorRepository.load(id: draft.doctorID)
        }.value
        guard let doctor else {
            throw AppointmentSaveError.missingDoctor
        }

        if draft.endsAtEnabled, draft.endsAt < draft.scheduledAt {
            throw AppointmentSaveError.invalidDateRange
        }

        let existingRecord = try await Task.detached(priority: .userInitiated) {
            try draft.id.flatMap { try appointmentRepository.load(id: $0) }
        }.value
        if let requestID = existingRecord?.notificationRequestID {
            await notificationService.removePendingNotification(requestID: requestID)
        }

        let id = try await Task.detached(priority: .userInitiated) {
            try appointmentRepository.save(draft: draft)
        }.value
        let savedRecord = try await Task.detached(priority: .userInitiated) {
            try appointmentRepository.load(id: id)
        }.value
        guard let savedRecord else {
            return id
        }

        if savedRecord.reminderEnabled {
            let result = await notificationService.scheduleAppointmentReminder(for: savedRecord, doctor: doctor)
            try await Task.detached(priority: .userInitiated) {
                try appointmentRepository.updateReminder(id: id, status: result.status, requestID: result.requestID)
            }.value
        } else {
            try await Task.detached(priority: .userInitiated) {
                try appointmentRepository.updateReminder(id: id, status: .notRequested, requestID: nil)
            }.value
        }

        return id
    }
}

struct DeleteAppointmentUseCase {
    let appointmentRepository: AppointmentRepository
    let notificationService: NotificationService

    func execute(id: UUID) async throws {
        let appointmentRepository = appointmentRepository
        let record = try await Task.detached(priority: .userInitiated) {
            try appointmentRepository.load(id: id)
        }.value
        if let requestID = record?.notificationRequestID {
            await notificationService.removePendingNotification(requestID: requestID)
        }

        try await Task.detached(priority: .userInitiated) {
            try appointmentRepository.softDelete(id: id)
        }.value
    }
}

@MainActor
@Observable
final class DoctorHubController {
    private let doctorRepository: DoctorRepository
    private let appointmentRepository: AppointmentRepository

    private(set) var doctors: [DoctorRecord] = []
    private(set) var doctorsByID: [UUID: DoctorRecord] = [:]
    private(set) var upcomingAppointments: [AppointmentRecord] = []
    private(set) var upcomingAppointmentItems: [UpcomingAppointmentListItem] = []
    var errorMessage: String?

    init(doctorRepository: DoctorRepository, appointmentRepository: AppointmentRepository) {
        self.doctorRepository = doctorRepository
        self.appointmentRepository = appointmentRepository
        Task { await reloadAll() }
    }

    func reloadAll() async {
        do {
            try await reloadDoctors()
            try await reloadAppointments()
            errorMessage = nil
        } catch {
            errorMessage = "Ärzte und Termine konnten nicht geladen werden."
        }
    }

    func reloadDoctors() async throws {
        let repository = doctorRepository
        doctors = try await Task.detached(priority: .userInitiated) {
            try repository.fetchAll()
        }.value
        doctorsByID = Dictionary(uniqueKeysWithValues: doctors.map { ($0.id, $0) })
        rebuildUpcomingAppointmentItems()
    }

    func reloadAppointments(limit: Int = 20) async throws {
        let repository = appointmentRepository
        upcomingAppointments = try await Task.detached(priority: .userInitiated) {
            try repository.fetchUpcoming(limit: limit)
        }.value
        rebuildUpcomingAppointmentItems()
    }

    private func rebuildUpcomingAppointmentItems() {
        upcomingAppointmentItems = upcomingAppointments.compactMap { appointment in
            guard let doctorID = appointment.doctorID, let doctor = doctorsByID[doctorID] else {
                return nil
            }

            return UpcomingAppointmentListItem(appointment: appointment, doctor: doctor)
        }
    }
}

@MainActor
@Observable
final class DoctorEditorController {
    private static let specialtyPriority: [String] = [
        "Neurologie",
        "Innere Medizin",
        "Psychiatrie",
        "Psychiatrie und psychotherapeutische Medizin",
        "Kinder- und Jugendpsychiatrie",
        "Kinder- und Jugendheilkunde",
        "Frauenheilkunde und Geburtshilfe",
        "Hals-, Nasen- und Ohrenheilkunde",
        "Augenheilkunde und Optometrie",
        "Haut- und Geschlechtskrankheiten",
        "Orthopädie und orthopädische Chirurgie",
        "Unfallchirurgie",
        "Physikalische Medizin",
        "Lungenkrankheiten",
        "Radiologie",
        "Urologie",
        "Chirurgie"
    ]

    var draft: DoctorDraft
    var searchText = ""
    private(set) var searchResults: [DoctorDirectoryRecord] = []
    private(set) var groupedSearchResults: [DoctorDirectorySection] = []
    private(set) var sourceAttribution: (label: String, url: String)
    var validationMessage: String?

    private let saveDoctorUseCase: SaveDoctorUseCase
    private let directoryRepository: DoctorDirectoryRepository
    private var searchTask: Task<Void, Never>?

    init(
        doctor: DoctorRecord?,
        doctorRepository: DoctorRepository,
        directoryRepository: DoctorDirectoryRepository
    ) {
        self.draft = doctor.map(DoctorDraft.from(record:)) ?? .makeNew()
        self.saveDoctorUseCase = SaveDoctorUseCase(repository: doctorRepository)
        self.directoryRepository = directoryRepository
        self.sourceAttribution = (
            "ÖGK Vertragspartner Fachärztinnen und Fachärzte",
            "https://www.gesundheitskasse.at/cdscontent/?contentid=10007.884365"
        )
        refreshSearch()
        Task { await refreshSourceAttribution() }
    }

    func refreshSearch() {
        let repository = directoryRepository
        let searchText = searchText
        Task {
            let results = await Task.detached(priority: .userInitiated) {
                (try? repository.fetchEntries(searchText: searchText)) ?? []
            }.value
            searchResults = results
            groupedSearchResults = Self.makeGroupedSearchResults(from: results)
        }
    }

    func scheduleSearchRefresh() {
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else {
                return
            }
            self.refreshSearch()
        }
    }

    private func refreshSourceAttribution() async {
        let repository = directoryRepository
        sourceAttribution = await Task.detached(priority: .utility) {
            repository.sourceAttribution()
        }.value
    }

    private static func makeGroupedSearchResults(from searchResults: [DoctorDirectoryRecord]) -> [DoctorDirectorySection] {
        let grouped = Dictionary(grouping: searchResults) { entry in
            let trimmed = entry.specialty.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Sonstige Fachgebiete" : trimmed
        }

        return grouped
            .map { specialty, entries in
                DoctorDirectorySection(
                    title: specialty,
                    entries: entries.sorted {
                        if $0.postalCodeSortKey == $1.postalCodeSortKey {
                            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                        }

                        return $0.postalCodeSortKey.localizedStandardCompare($1.postalCodeSortKey) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                let lhsIndex = Self.specialtyPriority.firstIndex(of: lhs.title) ?? .max
                let rhsIndex = Self.specialtyPriority.firstIndex(of: rhs.title) ?? .max

                if lhsIndex == rhsIndex {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }

                return lhsIndex < rhsIndex
            }
    }

    func applyDirectoryEntry(_ entry: DoctorDirectoryRecord) {
        draft.applyDirectoryEntry(entry)
    }

    func applyDoctor(_ doctor: DoctorRecord) {
        draft = DoctorDraft.from(record: doctor)
    }

    func save(onSaved: @escaping (UUID) -> Void) {
        Task {
            do {
                let id = try await saveDoctorUseCase.execute(draft)
                validationMessage = nil
                onSaved(id)
            } catch {
                validationMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
@Observable
final class AppointmentEditorController {
    var draft: AppointmentDraft
    var validationMessage: String?
    var saveMessageVisible = false

    private let saveAppointmentUseCase: SaveAppointmentUseCase
    private let appointmentRepository: AppointmentRepository

    init(
        appointment: AppointmentRecord?,
        doctor: DoctorRecord,
        appointmentRepository: AppointmentRepository,
        doctorRepository: DoctorRepository,
        notificationService: NotificationService
    ) {
        self.draft = appointment.map(AppointmentDraft.from(record:)) ?? .makeNew(doctor: doctor)
        self.appointmentRepository = appointmentRepository
        self.saveAppointmentUseCase = SaveAppointmentUseCase(
            appointmentRepository: appointmentRepository,
            doctorRepository: doctorRepository,
            notificationService: notificationService
        )
    }

    func loadAppointment(id: UUID) async {
        let repository = appointmentRepository
        guard let appointment = await Task.detached(priority: .userInitiated, operation: {
            try? repository.load(id: id)
        }).value else {
            return
        }

        draft = AppointmentDraft.from(record: appointment)
    }

    func save(onSaved: @escaping (UUID) -> Void) {
        Task {
            do {
                let id = try await saveAppointmentUseCase.execute(draft)
                await MainActor.run {
                    validationMessage = nil
                    saveMessageVisible = true
                    onSaved(id)
                }
            } catch {
                await MainActor.run {
                    validationMessage = error.localizedDescription
                }
            }
        }
    }
}
