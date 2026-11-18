import EventKit
import Observation
import SwiftUI

@MainActor
@Observable
final class EventStore {
    var permission = EKEventStore.authorizationStatus(for: .event)
    var events: [CalendarEvent] = []

    private let calendarStore = EKEventStore()

    func askForAccess() async {
        if permission == .notDetermined || permission == .writeOnly {
            _ = try? await calendarStore.requestFullAccessToEvents()
        }
        permission = EKEventStore.authorizationStatus(for: .event)
    }

    func load(_ date: Date) {
        permission = EKEventStore.authorizationStatus(for: .event)

        guard permission == .fullAccess,
              let day = Calendar.current.dateInterval(of: .day, for: date) else {
            events = []
            return
        }

        let search = calendarStore.predicateForEvents(
            withStart: day.start,
            end: day.end,
            calendars: nil
        )

        events = calendarStore.events(matching: search).compactMap { event in
            guard let start = event.startDate, let end = event.endDate else { return nil }

            return CalendarEvent(
                id: "\(event.eventIdentifier ?? "")-\(start.timeIntervalSinceReferenceDate)",
                title: event.title ?? "Untitled Event",
                start: start,
                end: end,
                location: event.location ?? "",
                color: event.calendar?.cgColor.map { Color(cgColor: $0) } ?? .purple,
                isAllDay: event.isAllDay
            )
        }
        .sorted { $0.start < $1.start }
    }

    func add(title: String, start: Date, end: Date, location: String) throws {
        guard !title.isEmpty, end > start else { throw CalendarError.invalidEvent }
        guard permission == .fullAccess else { throw CalendarError.noAccess }
        guard let calendar = calendarStore.defaultCalendarForNewEvents else {
            throw CalendarError.noCalendar
        }

        let event = EKEvent(eventStore: calendarStore)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.location = location.isEmpty ? nil : location

        try calendarStore.save(event, span: .thisEvent)
    }
}

private enum CalendarError: LocalizedError {
    case noAccess, noCalendar, invalidEvent

    var errorDescription: String? {
        switch self {
        case .noAccess: "Allow Calendar access in Settings first."
        case .noCalendar: "Create a calendar in the Calendar app first."
        case .invalidEvent: "Give the event a title and a valid time."
        }
    }
}

// hello is this proof that i did it idk, i changed most of the code
