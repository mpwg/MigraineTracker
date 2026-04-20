import Foundation
import Observation

enum DoctorSource: String, CaseIterable, Codable, Identifiable {
    case manual = "Manuell"
    case oegkDirectory = "ÖGK-Suchkatalog"

    var id: String { rawValue }
}

enum AppointmentReminderStatus: String, CaseIterable, Codable, Identifiable {
    case notRequested = "Nicht angefragt"
    case authorized = "Erlaubt"
    case denied = "Abgelehnt"
    case scheduled = "Geplant"
    case failed = "Fehlgeschlagen"

    var id: String { rawValue }
}

struct DoctorRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let name: String
    let specialty: String
    let street: String
    let city: String
    let state: String
    let postalCode: String?
    let phone: String
    let email: String
    let notes: String
    let source: DoctorSource
    let appointments: [AppointmentRecord]

    var isDeleted: Bool {
        deletedAt != nil
    }

    var addressLine: String {
        [street, [postalCode, city].compactMap { $0 }.joined(separator: " "), state]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
    }
}

struct DoctorDirectoryRecord: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let specialty: String
    let street: String
    let city: String
    let state: String
    let postalCode: String?
    let sourceLabel: String
    let sourceURL: String

    var addressLine: String {
        [street, [postalCode, city].compactMap { $0 }.joined(separator: " "), state]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
    }

    var postalCodeSortKey: String {
        postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "9999"
    }
}

struct DoctorDirectorySection: Identifiable, Equatable, Sendable {
    let title: String
    let entries: [DoctorDirectoryRecord]

    var id: String { title }
}

struct AppointmentRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let doctorID: UUID?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let scheduledAt: Date
    let endsAt: Date?
    let practiceName: String
    let addressText: String
    let note: String
    let reminderEnabled: Bool
    let reminderLeadTimeMinutes: Int
    let reminderStatus: AppointmentReminderStatus
    let notificationRequestID: String?

    var isDeleted: Bool {
        deletedAt != nil
    }
}

struct DoctorDraft: Equatable, Sendable {
    var id: UUID?
    var name: String
    var specialty: String
    var street: String
    var city: String
    var state: String
    var postalCode: String
    var phone: String
    var email: String
    var notes: String
    var source: DoctorSource

    static func makeNew() -> DoctorDraft {
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

    static func from(record: DoctorRecord) -> DoctorDraft {
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

    mutating func applyDirectoryEntry(_ entry: DoctorDirectoryRecord) {
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
    var id: UUID?
    var doctorID: UUID
    var scheduledAt: Date
    var endsAtEnabled: Bool
    var endsAt: Date
    var practiceName: String
    var addressText: String
    var note: String
    var reminderEnabled: Bool
    var reminderLeadTimeMinutes: Int

    static func makeNew(doctor: DoctorRecord) -> AppointmentDraft {
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

    static func from(record: AppointmentRecord) -> AppointmentDraft {
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
    let status: AppointmentReminderStatus
    let requestID: String?
}

protocol DoctorRepository {
    func fetchAll() throws -> [DoctorRecord]
    func load(id: UUID) throws -> DoctorRecord?
    @discardableResult
    func save(draft: DoctorDraft) throws -> UUID
    func softDelete(id: UUID) throws
}

protocol DoctorDirectoryRepository {
    func fetchEntries(searchText: String?) throws -> [DoctorDirectoryRecord]
    func sourceAttribution() -> (label: String, url: String)
}

protocol AppointmentRepository {
    func fetchUpcoming(limit: Int?) throws -> [AppointmentRecord]
    func fetchUpcoming(for doctorID: UUID) throws -> [AppointmentRecord]
    func load(id: UUID) throws -> AppointmentRecord?
    @discardableResult
    func save(draft: AppointmentDraft) throws -> UUID
    func updateReminder(id: UUID, status: AppointmentReminderStatus, requestID: String?) throws
    func softDelete(id: UUID) throws
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
    func execute(_ draft: DoctorDraft) throws -> UUID {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DoctorSaveError.missingName
        }

        return try repository.save(draft: draft)
    }
}

struct SaveAppointmentUseCase {
    let appointmentRepository: AppointmentRepository
    let doctorRepository: DoctorRepository
    let notificationService: NotificationService

    @discardableResult
    func execute(_ draft: AppointmentDraft) async throws -> UUID {
        guard let doctor = try doctorRepository.load(id: draft.doctorID) else {
            throw AppointmentSaveError.missingDoctor
        }

        if draft.endsAtEnabled, draft.endsAt < draft.scheduledAt {
            throw AppointmentSaveError.invalidDateRange
        }

        let existingRecord = draft.id.flatMap { try? appointmentRepository.load(id: $0) } ?? nil
        if let requestID = existingRecord?.notificationRequestID {
            await notificationService.removePendingNotification(requestID: requestID)
        }

        let id = try appointmentRepository.save(draft: draft)
        let savedRecord = try appointmentRepository.load(id: id)
        guard let savedRecord else {
            return id
        }

        if savedRecord.reminderEnabled {
            let result = await notificationService.scheduleAppointmentReminder(for: savedRecord, doctor: doctor)
            try appointmentRepository.updateReminder(id: id, status: result.status, requestID: result.requestID)
        } else {
            try appointmentRepository.updateReminder(id: id, status: .notRequested, requestID: nil)
        }

        return id
    }
}

struct DeleteAppointmentUseCase {
    let appointmentRepository: AppointmentRepository
    let notificationService: NotificationService

    func execute(id: UUID) async throws {
        if let record = try appointmentRepository.load(id: id), let requestID = record.notificationRequestID {
            await notificationService.removePendingNotification(requestID: requestID)
        }

        try appointmentRepository.softDelete(id: id)
    }
}

@MainActor
@Observable
final class DoctorHubController {
    private let doctorRepository: DoctorRepository
    private let appointmentRepository: AppointmentRepository

    private(set) var doctors: [DoctorRecord] = []
    private(set) var upcomingAppointments: [AppointmentRecord] = []
    var errorMessage: String?

    init(doctorRepository: DoctorRepository, appointmentRepository: AppointmentRepository) {
        self.doctorRepository = doctorRepository
        self.appointmentRepository = appointmentRepository
        reload()
    }

    func reload() {
        do {
            doctors = try doctorRepository.fetchAll()
            upcomingAppointments = try appointmentRepository.fetchUpcoming(limit: 20)
            errorMessage = nil
        } catch {
            errorMessage = "Ärzte und Termine konnten nicht geladen werden."
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
    private(set) var sourceAttribution: (label: String, url: String)
    var validationMessage: String?

    private let saveDoctorUseCase: SaveDoctorUseCase
    private let directoryRepository: DoctorDirectoryRepository

    init(
        doctor: DoctorRecord?,
        doctorRepository: DoctorRepository,
        directoryRepository: DoctorDirectoryRepository
    ) {
        self.draft = doctor.map(DoctorDraft.from(record:)) ?? .makeNew()
        self.saveDoctorUseCase = SaveDoctorUseCase(repository: doctorRepository)
        self.directoryRepository = directoryRepository
        self.sourceAttribution = directoryRepository.sourceAttribution()
        refreshSearch()
    }

    func refreshSearch() {
        searchResults = (try? directoryRepository.fetchEntries(searchText: searchText)) ?? []
    }

    var groupedSearchResults: [DoctorDirectorySection] {
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

    func save(onSaved: @escaping (UUID) -> Void) {
        do {
            let id = try saveDoctorUseCase.execute(draft)
            validationMessage = nil
            onSaved(id)
        } catch {
            validationMessage = error.localizedDescription
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

    init(
        appointment: AppointmentRecord?,
        doctor: DoctorRecord,
        appointmentRepository: AppointmentRepository,
        doctorRepository: DoctorRepository,
        notificationService: NotificationService
    ) {
        self.draft = appointment.map(AppointmentDraft.from(record:)) ?? .makeNew(doctor: doctor)
        self.saveAppointmentUseCase = SaveAppointmentUseCase(
            appointmentRepository: appointmentRepository,
            doctorRepository: doctorRepository,
            notificationService: notificationService
        )
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
