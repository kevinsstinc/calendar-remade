import EventKit
import Observation
import SwiftUI

struct CalendarOption: Identifiable {
    let id: String
    let title: String
    let source: String
    let color: Color
}

@Observable
final class EventStore {
    private(set) var authorization: EKAuthorizationStatus
    private(set) var writableCalendars: [CalendarOption] = []
    private(set) var defaultCalendarID: String?

    private var localEvents: [CalendarEvent]
    private var eventColors: [String: Color.Resolved]
    private var revision = 0

    private let calendarStore = EKEventStore()
    private let defaults: UserDefaults?
    @ObservationIgnored private var storeObserver: (any NSObjectProtocol)?

    private static let localEventsKey = "calendarEvents"
    private static let colorsKey = "appleCalendarEventColors"

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        let decoder = JSONDecoder()
        localEvents = defaults?.data(forKey: Self.localEventsKey)
            .flatMap { try? decoder.decode([CalendarEvent].self, from: $0) }
            ?? (defaults == nil ? CalendarEvent.samples(on: .now) : [])
        eventColors = defaults?.data(forKey: Self.colorsKey)
            .flatMap { try? decoder.decode([String: Color.Resolved].self, from: $0) }
            ?? [:]
        authorization = EKEventStore.authorizationStatus(for: .event)

        if defaults != nil {
            storeObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            refresh()
        }
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    func requestCalendarAccess() async throws {
        guard defaults != nil else { return }
        defer { refresh() }
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined || status == .writeOnly {
            _ = try await calendarStore.requestFullAccessToEvents()
        }
    }

    func refresh() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        revision &+= 1
        guard authorization == .fullAccess, defaults != nil else {
            writableCalendars = []
            defaultCalendarID = nil
            return
        }

        writableCalendars = calendarStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map { calendar in
                CalendarOption(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    source: calendar.source?.title ?? "",
                    color: calendar.eventColor
                )
            }
            .sorted { lhs, rhs in
                if lhs.title == rhs.title {
                    return lhs.source.localizedStandardCompare(rhs.source) == .orderedAscending
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }

        let systemDefault = calendarStore.defaultCalendarForNewEvents?.calendarIdentifier
        defaultCalendarID = writableCalendars.first { $0.id == systemDefault }?.id
            ?? writableCalendars.first?.id
    }

    func events(on date: Date, calendar: Calendar) -> [CalendarEvent] {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return [] }
        let local = localEvents.filter { $0.overlaps(day) }
        let apple = appleEvents(in: day)
            .compactMap { snapshot($0) }
            .filter { $0.overlaps(day) }

        return (local + apple).sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    func event(withID id: CalendarEvent.ID) -> CalendarEvent? {
        switch id {
        case .local:
            return localEvents.first { $0.id == id }
        case .apple(let reference):
            return findOccurrence(reference).flatMap { snapshot($0) }
        }
    }

    func add(_ draft: CalendarEvent) throws -> CalendarEvent {
        try saveToCalendar(draft, original: nil)
    }

    func update(_ draft: CalendarEvent, basedOn original: CalendarEvent) throws -> CalendarEvent {
        if original.isAppleCalendarEvent {
            return try saveToCalendar(draft, original: original)
        }

        try validate(draft, original: original)
        guard let index = localEvents.firstIndex(where: { $0.id == original.id }) else {
            throw CalendarStoreError.eventUnavailable
        }
        localEvents[index] = draft
        persistLocalEvents()
        return draft
    }

    private func saveToCalendar(_ draft: CalendarEvent, original: CalendarEvent?) throws -> CalendarEvent {
        try validate(draft, original: original)
        try checkAuthorization()

        let event: EKEvent
        if let original {
            event = try editableOccurrence(original)
            if draft.targetCalendarID != original.targetCalendarID {
                event.calendar = try writableCalendar(draft.targetCalendarID)
            }
        } else {
            event = EKEvent(eventStore: calendarStore)
            event.calendar = try writableCalendar(draft.targetCalendarID ?? defaultCalendarID)
        }

        // Setting location again can replace the event's existing map coordinates.
        if draft.title != original?.title { event.title = draft.title }
        if draft.location != original?.location { event.location = draft.location.isEmpty ? nil : draft.location }
        if draft.notes != original?.notes { event.notes = draft.notes.isEmpty ? nil : draft.notes }

        let changedAllDay = draft.isAllDay != original?.isAllDay
        if changedAllDay {
            event.isAllDay = draft.isAllDay
            event.timeZone = draft.isAllDay ? nil : .current
        }
        if changedAllDay || draft.start != original?.start { event.startDate = draft.start }
        if changedAllDay || draft.end != original?.end { event.endDate = eventKitEndDate(for: draft) }

        if original == nil || event.hasChanges {
            try calendarStore.save(event, span: .thisEvent, commit: true)
        }
        saveColor(draft, original: original, for: event)
        refresh()
        return snapshot(event) ?? original ?? draft
    }

    private func saveColor(_ draft: CalendarEvent, original: CalendarEvent?, for event: EKEvent) {
        guard let calendar = event.calendar, let newKey = reference(to: event)?.colorKey else { return }
        let oldKey = original?.appleOccurrence?.colorKey
        let oldColor = original?.resolvedColor ?? calendar.eventColor.resolve(in: EnvironmentValues())

        if draft.resolvedColor != oldColor {
            if let oldKey, oldKey != newKey {
                eventColors.removeValue(forKey: oldKey)
            }
            eventColors[newKey] = draft.resolvedColor
        } else if let oldKey, oldKey != newKey,
                  let color = eventColors.removeValue(forKey: oldKey) {
            eventColors[newKey] = color
        } else {
            return
        }
        persistColors()
    }

    func delete(_ event: CalendarEvent) throws {
        if let reference = event.appleOccurrence {
            try checkAuthorization()
            let occurrence = try editableOccurrence(event)
            try calendarStore.remove(occurrence, span: .thisEvent, commit: true)
            if eventColors.removeValue(forKey: reference.colorKey) != nil {
                persistColors()
            }
            refresh()
        } else {
            localEvents.removeAll { $0.id == event.id }
            persistLocalEvents()
        }
    }

    private func appleEvents(in interval: DateInterval, calendarID: String? = nil) -> [EKEvent] {
        // EventKit changes don't update SwiftUI on their own.
        _ = revision
        guard defaults != nil, authorization == .fullAccess,
              EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        var calendars: [EKCalendar]?
        if let calendarID {
            guard let calendar = calendarStore.calendar(withIdentifier: calendarID) else { return [] }
            calendars = [calendar]
        }
        let predicate = calendarStore.predicateForEvents(
            withStart: interval.start, end: interval.end, calendars: calendars
        )
        return calendarStore.events(matching: predicate)
    }

    private func findOccurrence(_ reference: CalendarEvent.AppleOccurrence) -> EKEvent? {
        // An EventKit id can belong to more than one occurrence of a repeating event.
        let search = DateInterval(start: reference.start.addingTimeInterval(-1), duration: 2)
        return appleEvents(in: search, calendarID: reference.calendarID).first { self.reference(to: $0) == reference }
    }

    private func editableOccurrence(_ original: CalendarEvent) throws -> EKEvent {
        guard let reference = original.appleOccurrence, let event = findOccurrence(reference) else {
            throw CalendarStoreError.eventUnavailable
        }
        guard event.calendar?.allowsContentModifications == true else {
            throw CalendarStoreError.readOnly
        }
        if let lastModified = original.lastModified, let current = event.lastModifiedDate,
           current != lastModified {
            throw CalendarStoreError.eventChanged
        }
        return event
    }

    private func writableCalendar(_ identifier: String?) throws -> EKCalendar {
        guard let identifier else { throw CalendarStoreError.noWritableCalendar }
        guard let calendar = calendarStore.calendar(withIdentifier: identifier),
              calendar.allowsContentModifications else { throw CalendarStoreError.calendarUnavailable }
        return calendar
    }

    private func checkAuthorization() throws {
        guard defaults != nil, EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            refresh()
            throw CalendarStoreError.accessRequired
        }
    }

    private func validate(_ event: CalendarEvent, original: CalendarEvent?) throws {
        let wasInstant = original.map { !$0.isAllDay && $0.start == $0.end } ?? false
        let keepsInstant = wasInstant && !event.isAllDay && event.start == event.end
        guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              event.end > event.start || keepsInstant else {
            throw CalendarStoreError.invalidEvent
        }
    }

    private func eventKitEndDate(for event: CalendarEvent) -> Date {
        // EventKit's all-day setter uses the last included day. The app uses the following midnight.
        event.isAllDay ? event.end.addingTimeInterval(-1) : event.end
    }

    private func exclusiveAllDayEnd(from rawEnd: Date, start: Date) -> Date {
        let calendar = Calendar.current
        if rawEnd > start && calendar.startOfDay(for: rawEnd) == rawEnd {
            return rawEnd
        }
        return calendar.dateInterval(of: .day, for: max(start, rawEnd))?.end ?? rawEnd
    }

    private func reference(to event: EKEvent) -> CalendarEvent.AppleOccurrence? {
        guard let eventID = event.eventIdentifier, let calendar = event.calendar,
              let start = event.startDate else { return nil }
        let repeats = event.hasRecurrenceRules || event.isDetached
        return .init(
            calendarID: calendar.calendarIdentifier,
            eventID: eventID,
            start: start,
            occurrenceDate: repeats ? event.occurrenceDate : nil
        )
    }

    private func snapshot(_ event: EKEvent) -> CalendarEvent? {
        guard let calendar = event.calendar, let end = event.endDate,
              let reference = reference(to: event) else { return nil }

        let title = event.title ?? ""
        var snapshot = CalendarEvent(
            title: title.isEmpty ? "Untitled Event" : title,
            start: reference.start,
            end: event.isAllDay ? exclusiveAllDayEnd(from: end, start: reference.start) : end,
            location: event.location ?? "",
            notes: event.notes ?? "",
            calendar: calendar.title,
            color: eventColors[reference.colorKey].map { Color($0) } ?? calendar.eventColor
        )
        snapshot.appleOccurrence = reference
        snapshot.targetCalendarID = reference.calendarID
        snapshot.lastModified = event.lastModifiedDate
        snapshot.isEditable = calendar.allowsContentModifications
        snapshot.isRecurring = event.hasRecurrenceRules || event.isDetached
        snapshot.isAllDay = event.isAllDay
        return snapshot
    }

    private func persistLocalEvents() {
        if let data = try? JSONEncoder().encode(localEvents) {
            defaults?.set(data, forKey: Self.localEventsKey)
        }
    }

    private func persistColors() {
        if let data = try? JSONEncoder().encode(eventColors) {
            defaults?.set(data, forKey: Self.colorsKey)
        }
    }
}

private extension EKCalendar {
    var eventColor: Color {
        cgColor.map { Color(cgColor: $0) } ?? .purple
    }
}

private enum CalendarStoreError: LocalizedError {
    case accessRequired, noWritableCalendar, calendarUnavailable, readOnly
    case eventUnavailable, eventChanged, invalidEvent

    var errorDescription: String? {
        switch self {
        case .accessRequired:
            return "Allow Full Access to Calendars in Settings to change Apple Calendar events."
        case .noWritableCalendar:
            return "Create a calendar in Apple Calendar before adding events."
        case .calendarUnavailable:
            return "That calendar is no longer available for editing. Choose another calendar."
        case .readOnly:
            return "This calendar is read-only."
        case .eventUnavailable:
            return "This event was moved or removed from Apple Calendar."
        case .eventChanged:
            return "This event changed in Apple Calendar. Close the editor and reopen it to see the latest details."
        case .invalidEvent:
            return "Enter a title and a valid end date."
        }
    }
}
