import Foundation
import UserNotifications

enum NotificationServiceError: LocalizedError, Equatable, Sendable {
    case denied
    case missingDate
    case tooSoon

    var errorDescription: String? {
        switch self {
        case .denied: "Notifications are off. You can enable them for RoleReady in iOS Settings."
        case .missingDate: "Add an interview or closing date before creating a reminder."
        case .tooSoon: "The interview is too close to schedule a useful reminder. Open your prep deck now instead."
        }
    }
}

struct NotificationService {
    func requestPermission() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .denied { throw NotificationServiceError.denied }
        if settings.authorizationStatus == .notDetermined {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if !granted { throw NotificationServiceError.denied }
        }
    }

    func scheduleInterviewReminder(opportunityID: UUID, interviewDate: Date) async throws -> Date {
        try await requestPermission()
        let now = Date()
        let reminderDate = try reminderDate(for: interviewDate, now: now)
        let leadTime = interviewDate.timeIntervalSince(reminderDate)
        let content = UNMutableNotificationContent()
        content.title = leadTime >= 24 * 60 * 60 ? "Interview tomorrow" : "Interview coming up"
        content.body = "Your private prep deck is ready when you are."
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let request = UNNotificationRequest(
            identifier: "roleready.interview.\(opportunityID.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
        return reminderDate
    }

    func reminderDate(for interviewDate: Date, now: Date = Date()) throws -> Date {
        let interval = interviewDate.timeIntervalSince(now)
        let leadTime: TimeInterval
        if interval > 24 * 60 * 60 {
            leadTime = 24 * 60 * 60
        } else if interval > 2 * 60 * 60 {
            leadTime = 60 * 60
        } else if interval > 15 * 60 {
            leadTime = 10 * 60
        } else {
            throw NotificationServiceError.tooSoon
        }
        return interviewDate.addingTimeInterval(-leadTime)
    }

    func cancelReminders(for opportunityID: UUID) {
        let identifiers = [
            "roleready.interview.\(opportunityID.uuidString)",
            "roleready.deadline.\(opportunityID.uuidString)"
        ]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancelAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
