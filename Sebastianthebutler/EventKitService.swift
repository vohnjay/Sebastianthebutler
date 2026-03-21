//
//  EventKitService.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import EventKit
import SwiftUI

// MARK: - Lightweight wrappers (EKEvent/EKReminder aren't Identifiable)

struct BriefingEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarHex: String   // hex color string, e.g. "#FF3B30"

    var timeLabel: String {
        guard !isAllDay else { return "All day" }
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"; f.pmSymbol = "pm"
        return f.string(from: startDate).lowercased()
    }
}

struct BriefingReminder: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    var isCompleted: Bool

    var dueDateLabel: String {
        guard let d = dueDate else { return "today" }
        let f = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            f.dateFormat = "h:mma"; f.amSymbol = "am"; f.pmSymbol = "pm"
            return f.string(from: d).lowercased()
        }
        f.dateStyle = .short; f.timeStyle = .none
        return f.string(from: d)
    }
}

// MARK: - Service

@Observable
final class EventKitService {
    static let shared = EventKitService()
    private let store = EKEventStore()

    var calendarAuthorized  = false
    var remindersAuthorized = false

    private init() {}

    // MARK: – Permission requests

    func requestCalendarAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            calendarAuthorized = granted
        } catch {
            calendarAuthorized = false
        }
    }

    func requestReminderAccess() async {
        do {
            let granted = try await store.requestFullAccessToReminders()
            remindersAuthorized = granted
        } catch {
            remindersAuthorized = false
        }
    }

    // MARK: – Today's events

    func todaysEvents() -> [BriefingEvent] {
        guard calendarAuthorized else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        return events
            .filter { !$0.isAllDay || $0.title != nil }
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
            .map { event in
                let hex = event.calendar.cgColor.map { uiColor(from: $0) } ?? "#636366"
                return BriefingEvent(
                    id:          event.eventIdentifier ?? UUID().uuidString,
                    title:       event.title ?? "Untitled",
                    startDate:   event.startDate,
                    endDate:     event.endDate,
                    isAllDay:    event.isAllDay,
                    calendarHex: hex
                )
            }
    }

    // MARK: – Today's reminders

    func todaysReminders() async -> [BriefingReminder] {
        guard remindersAuthorized else { return [] }

        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                continuation.resume(returning: [])
                return
            }
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: start,
                                                                   ending: end,
                                                                   calendars: nil)
            store.fetchReminders(matching: predicate) { reminders in
                let results = (reminders ?? [])
                    .prefix(6)
                    .map { r in
                        BriefingReminder(
                            id:          r.calendarItemIdentifier,
                            title:       r.title ?? "Untitled",
                            dueDate:     r.dueDateComponents?.date,
                            isCompleted: r.isCompleted
                        )
                    }
                continuation.resume(returning: Array(results))
            }
        }
    }

    // MARK: – Helpers

    private func uiColor(from cgColor: CGColor) -> String {
        let c = cgColor.components ?? [0.4, 0.4, 0.4, 1]
        let r = Int((c[0] * 255).rounded())
        let g = Int((c[1] * 255).rounded())
        let b = Int((c[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
