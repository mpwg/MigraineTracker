import Foundation
import UserNotifications

final class UserNotificationService: NotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func scheduleAppointmentReminder(for appointment: AppointmentRecord, doctor: DoctorRecord) async -> ReminderSchedulingResult {
        let settings = await center.notificationSettings()
        let authorizationStatus = settings.authorizationStatus

        let isAuthorized: Bool
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else {
            return ReminderSchedulingResult(status: .denied, requestID: nil)
        }

        let reminderDate = appointment.scheduledAt.addingTimeInterval(TimeInterval(-appointment.reminderLeadTimeMinutes * 60))
        let finalTriggerDate = max(reminderDate, .now.addingTimeInterval(5))
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: finalTriggerDate)
        let requestID = appointment.notificationRequestID ?? "doctor-appointment-\(appointment.id.uuidString)"

        let content = UNMutableNotificationContent()
        content.title = "Arzttermin"
        content.body = "\(doctor.name) am \(appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))"
        content.sound = .default

        if !appointment.practiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.subtitle = appointment.practiceName
        } else if !doctor.specialty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.subtitle = doctor.specialty
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)

        do {
            try await center.add(request)
            return ReminderSchedulingResult(status: .scheduled, requestID: requestID)
        } catch {
            return ReminderSchedulingResult(status: .failed, requestID: nil)
        }
    }

    func removePendingNotification(requestID: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        center.removeDeliveredNotifications(withIdentifiers: [requestID])
    }
}
