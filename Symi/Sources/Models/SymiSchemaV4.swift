import Foundation
import SwiftData

enum SymiSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            Episode.self,
            MedicationEntry.self,
            MedicationDefinition.self,
            WeatherSnapshot.self,
            Doctor.self,
            DoctorAppointment.self,
            DoctorDirectoryEntry.self
        ]
    }

    @Model
    final class Episode {
        @Attribute(.unique) var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var updatedAt: Date = Date.now
        var deletedAt: Date?
        var typeRaw: String
        var intensity: Int
        var painLocation: String
        var painCharacter: String
        var notes: String
        var symptomsStorage: String
        var triggersStorage: String
        var functionalImpact: String
        var menstruationStatusRaw: String

        @Relationship(deleteRule: .cascade, inverse: \MedicationEntry.episode)
        var medications: [MedicationEntry]

        @Relationship(deleteRule: .cascade, inverse: \WeatherSnapshot.episode)
        var weatherSnapshot: WeatherSnapshot?

        init(
            id: UUID = UUID(),
            startedAt: Date,
            endedAt: Date? = nil,
            updatedAt: Date = .now,
            deletedAt: Date? = nil,
            typeRaw: String,
            intensity: Int,
            painLocation: String = "",
            painCharacter: String = "",
            notes: String = "",
            symptomsStorage: String = "",
            triggersStorage: String = "",
            functionalImpact: String = "",
            menstruationStatusRaw: String = MenstruationStatus.unknown.rawValue,
            medications: [MedicationEntry] = []
        ) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.typeRaw = typeRaw
            self.intensity = intensity
            self.painLocation = painLocation
            self.painCharacter = painCharacter
            self.notes = notes
            self.symptomsStorage = symptomsStorage
            self.triggersStorage = triggersStorage
            self.functionalImpact = functionalImpact
            self.menstruationStatusRaw = menstruationStatusRaw
            self.medications = medications
        }
    }

    @Model
    final class MedicationEntry {
        @Attribute(.unique) var id: UUID
        var name: String
        var categoryRaw: String
        var dosage: String
        var quantity: Int
        var takenAt: Date
        var effectivenessRaw: String
        var reliefStartedAt: Date?
        var isRepeatDose: Bool
        var episode: Episode?

        init(
            id: UUID = UUID(),
            name: String,
            categoryRaw: String,
            dosage: String,
            quantity: Int = 1,
            takenAt: Date,
            effectivenessRaw: String,
            reliefStartedAt: Date? = nil,
            isRepeatDose: Bool = false,
            episode: Episode? = nil
        ) {
            self.id = id
            self.name = name
            self.categoryRaw = categoryRaw
            self.dosage = dosage
            self.quantity = quantity
            self.takenAt = takenAt
            self.effectivenessRaw = effectivenessRaw
            self.reliefStartedAt = reliefStartedAt
            self.isRepeatDose = isRepeatDose
            self.episode = episode
        }
    }

    @Model
    final class MedicationDefinition {
        @Attribute(.unique) var catalogKey: String
        var groupID: String
        var groupTitle: String
        var groupFooter: String?
        var name: String
        var categoryRaw: String
        var suggestedDosage: String
        var sortOrder: Int
        var isCustom: Bool
        var createdAt: Date
        var updatedAt: Date = Date.now
        var deletedAt: Date?

        init(
            catalogKey: String,
            groupID: String,
            groupTitle: String,
            groupFooter: String? = nil,
            name: String,
            categoryRaw: String,
            suggestedDosage: String,
            sortOrder: Int,
            isCustom: Bool,
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil
        ) {
            self.catalogKey = catalogKey
            self.groupID = groupID
            self.groupTitle = groupTitle
            self.groupFooter = groupFooter
            self.name = name
            self.categoryRaw = categoryRaw
            self.suggestedDosage = suggestedDosage
            self.sortOrder = sortOrder
            self.isCustom = isCustom
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }
    }

    @Model
    final class WeatherSnapshot {
        @Attribute(.unique) var id: UUID
        var recordedAt: Date
        var temperature: Double?
        var condition: String
        var humidity: Double?
        var pressure: Double?
        var precipitation: Double?
        var weatherCode: Int?
        var source: String
        var episode: Episode?

        init(
            id: UUID = UUID(),
            recordedAt: Date,
            temperature: Double? = nil,
            condition: String = "",
            humidity: Double? = nil,
            pressure: Double? = nil,
            precipitation: Double? = nil,
            weatherCode: Int? = nil,
            source: String = "",
            episode: Episode? = nil
        ) {
            self.id = id
            self.recordedAt = recordedAt
            self.temperature = temperature
            self.condition = condition
            self.humidity = humidity
            self.pressure = pressure
            self.precipitation = precipitation
            self.weatherCode = weatherCode
            self.source = source
            self.episode = episode
        }
    }

    @Model
    final class Doctor {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
        var name: String
        var specialty: String
        var street: String
        var city: String
        var state: String
        var postalCode: String?
        var phone: String
        var email: String
        var notes: String
        var sourceRaw: String

        @Relationship(deleteRule: .cascade, inverse: \DoctorAppointment.doctor)
        var appointments: [DoctorAppointment]

        init(
            id: UUID = UUID(),
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil,
            name: String,
            specialty: String = "",
            street: String = "",
            city: String = "",
            state: String = "",
            postalCode: String? = nil,
            phone: String = "",
            email: String = "",
            notes: String = "",
            sourceRaw: String = "Manuell",
            appointments: [DoctorAppointment] = []
        ) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.name = name
            self.specialty = specialty
            self.street = street
            self.city = city
            self.state = state
            self.postalCode = postalCode
            self.phone = phone
            self.email = email
            self.notes = notes
            self.sourceRaw = sourceRaw
            self.appointments = appointments
        }
    }

    @Model
    final class DoctorAppointment {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
        var scheduledAt: Date
        var endsAt: Date?
        var practiceName: String
        var addressText: String
        var note: String
        var reminderEnabled: Bool
        var reminderLeadTimeMinutes: Int
        var notificationStatusRaw: String
        var notificationRequestID: String?
        var doctor: Doctor?

        init(
            id: UUID = UUID(),
            createdAt: Date = .now,
            updatedAt: Date = .now,
            deletedAt: Date? = nil,
            scheduledAt: Date,
            endsAt: Date? = nil,
            practiceName: String = "",
            addressText: String = "",
            note: String = "",
            reminderEnabled: Bool = true,
            reminderLeadTimeMinutes: Int = 24 * 60,
            notificationStatusRaw: String = "Nicht angefragt",
            notificationRequestID: String? = nil,
            doctor: Doctor? = nil
        ) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.scheduledAt = scheduledAt
            self.endsAt = endsAt
            self.practiceName = practiceName
            self.addressText = addressText
            self.note = note
            self.reminderEnabled = reminderEnabled
            self.reminderLeadTimeMinutes = reminderLeadTimeMinutes
            self.notificationStatusRaw = notificationStatusRaw
            self.notificationRequestID = notificationRequestID
            self.doctor = doctor
        }
    }

    @Model
    final class DoctorDirectoryEntry {
        @Attribute(.unique) var id: String
        var name: String
        var specialty: String
        var street: String
        var city: String
        var state: String
        var postalCode: String?
        var sourceLabel: String
        var sourceURL: String

        init(
            id: String,
            name: String,
            specialty: String,
            street: String,
            city: String,
            state: String,
            postalCode: String? = nil,
            sourceLabel: String,
            sourceURL: String
        ) {
            self.id = id
            self.name = name
            self.specialty = specialty
            self.street = street
            self.city = city
            self.state = state
            self.postalCode = postalCode
            self.sourceLabel = sourceLabel
            self.sourceURL = sourceURL
        }
    }
}
