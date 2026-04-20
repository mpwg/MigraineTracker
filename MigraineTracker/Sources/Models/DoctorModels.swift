import Foundation

extension Doctor {
    var source: DoctorSource {
        get { DoctorSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    func markUpdated(at date: Date = .now) {
        updatedAt = date
        deletedAt = nil
    }

    func markDeleted(at date: Date = .now) {
        updatedAt = date
        deletedAt = date
    }
}

extension DoctorAppointment {
    var reminderStatus: AppointmentReminderStatus {
        get { AppointmentReminderStatus(rawValue: notificationStatusRaw) ?? .notRequested }
        set { notificationStatusRaw = newValue.rawValue }
    }

    var isDeleted: Bool {
        deletedAt != nil
    }

    func markUpdated(at date: Date = .now) {
        updatedAt = date
        deletedAt = nil
    }

    func markDeleted(at date: Date = .now) {
        updatedAt = date
        deletedAt = date
    }
}
