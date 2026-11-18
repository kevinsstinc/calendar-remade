import SwiftUI
import EventKit
import Observation

struct CalendarOption: Identifiable {
    let id: String
    let title: String
    let source: String
    let color: Color
}

@Observable
final class EventStore {
    private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    private(set) var writableCalendars: [CalendarOption] = []
    private(set) var defaultCalendarID: String?

    private let store = EKEventStore()
    private let defaults: UserDefaults?
    private var localEvents: [CalendarEvent] = []
    private var colors: [String: Color.Resolved] = [:]
    private var revision = 0
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults

        if let data = defaults?.data(forKey: "calendarEvents"),
           let events = try? JSONDecoder().decode([CalendarEvent].self, from: data) {
            localEvents = events
        } else if defaults == nil {
            localEvents = CalendarEvent.samples(on: .now)
        }
        if let data = defaults?.data(forKey: "appleCalendarEventColors"),
           let saved = try? JSONDecoder().decode([String: Color.Resolved].self, from: data) {
            colors = saved
        }

        if defaults != nil {
            observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            refresh()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func requestCalendarAccess() async throws {
        guard defaults != nil else { return }
        defer { refresh() }
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined || status == .writeOnly {
            _ = try await store.requestFullAccessToEvents()
        }
    }

    func refresh() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        revision &+= 1
        guard defaults != nil, authorization == .fullAccess else {
            writableCalendars = []
            defaultCalendarID = nil
            return
        }

        writableCalendars = store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map {
                CalendarOption(id: $0.calendarIdentifier, title: $0.title,
                    source: $0.source?.title ?? "", color: calendarColor($0))
            }
            .sorted {
                if $0.title == $1.title {
                    return $0.source.localizedStandardCompare($1.source) == .orderedAscending
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }

        let id = store.defaultCalendarForNewEvents?.calendarIdentifier
        defaultCalendarID = writableCalendars.first { $0.id == id }?.id ?? writableCalendars.first?.id
    }

    func events(on date: Date, calendar: Calendar) -> [CalendarEvent] {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return [] }
        let local = localEvents.filter { $0.overlaps(day) }
        let apple = appleEvents(in: day).compactMap { makeEvent($0) }.filter { $0.overlaps(day) }

        return (local + apple).sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    func event(withID id: CalendarEvent.ID) -> CalendarEvent? {
        switch id {
        case .local: return localEvents.first { $0.id == id }
        case .apple(let reference): return findEvent(reference).flatMap { makeEvent($0) }
        }
    }

    func add(_ draft: CalendarEvent) throws -> CalendarEvent {
        try save(draft, original: nil)
    }

    func update(_ draft: CalendarEvent, basedOn original: CalendarEvent) throws -> CalendarEvent {
        if original.isAppleCalendarEvent { return try save(draft, original: original) }
        try validate(draft, original: original)
        guard let index = localEvents.firstIndex(where: { $0.id == original.id }) else {
            throw StoreError.eventUnavailable
        }
        localEvents[index] = draft
        saveLocalEvents()
        return draft
    }

    func delete(_ event: CalendarEvent) throws {
        if let reference = event.appleOccurrence {
            try requireAccess()
            try store.remove(editableEvent(event), span: .thisEvent, commit: true)
            if colors.removeValue(forKey: reference.colorKey) != nil { saveColors() }
            refresh()
        } else {
            localEvents.removeAll { $0.id == event.id }
            saveLocalEvents()
        }
    }

    private func save(_ draft: CalendarEvent, original: CalendarEvent?) throws -> CalendarEvent {
        try validate(draft, original: original)
        try requireAccess()

        let event: EKEvent
        if let original {
            event = try editableEvent(original)
            if draft.targetCalendarID != original.targetCalendarID {
                event.calendar = try findCalendar(draft.targetCalendarID)
            }
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = try findCalendar(draft.targetCalendarID ?? defaultCalendarID)
        }

        if draft.title != original?.title { event.title = draft.title }
        if draft.location != original?.location {
            event.location = draft.location.isEmpty ? nil : draft.location
        }
        if draft.notes != original?.notes { event.notes = draft.notes.isEmpty ? nil : draft.notes }

        let allDayChanged = draft.isAllDay != original?.isAllDay
        if allDayChanged {
            event.isAllDay = draft.isAllDay
            event.timeZone = draft.isAllDay ? nil : .current
        }
        if allDayChanged || draft.start != original?.start { event.startDate = draft.start }
        if allDayChanged || draft.end != original?.end {
            event.endDate = draft.isAllDay ? draft.end.addingTimeInterval(-1) : draft.end
        }

        if original == nil || event.hasChanges {
            try store.save(event, span: .thisEvent, commit: true)
        }

        if let calendar = event.calendar, let key = eventReference(event)?.colorKey {
            let oldKey = original?.appleOccurrence?.colorKey
            let oldColor = original?.resolvedColor ?? calendarColor(calendar).resolve(in: EnvironmentValues())
            if draft.resolvedColor != oldColor {
                if let oldKey, oldKey != key { colors.removeValue(forKey: oldKey) }
                colors[key] = draft.resolvedColor
                saveColors()
            } else if let oldKey, oldKey != key, let color = colors.removeValue(forKey: oldKey) {
                colors[key] = color
                saveColors()
            }
        }

        refresh()
        return makeEvent(event) ?? original ?? draft
    }

    private func appleEvents(in day: DateInterval, calendarID: String? = nil) -> [EKEvent] {
        _ = revision
        guard defaults != nil, authorization == .fullAccess,
              EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }

        var calendars: [EKCalendar]?
        if let calendarID {
            guard let calendar = store.calendar(withIdentifier: calendarID) else { return [] }
            calendars = [calendar]
        }
        let predicate = store.predicateForEvents(withStart: day.start, end: day.end, calendars: calendars)
        return store.events(matching: predicate)
    }

    private func findEvent(_ reference: CalendarEvent.AppleOccurrence) -> EKEvent? {
        let range = DateInterval(start: reference.start.addingTimeInterval(-1), duration: 2)
        return appleEvents(in: range, calendarID: reference.calendarID)
            .first { eventReference($0) == reference }
    }

    private func editableEvent(_ original: CalendarEvent) throws -> EKEvent {
        guard let reference = original.appleOccurrence, let event = findEvent(reference) else {
            throw StoreError.eventUnavailable
        }
        guard event.calendar?.allowsContentModifications == true else { throw StoreError.readOnly }
        if let old = original.lastModified, let current = event.lastModifiedDate, old != current {
            throw StoreError.eventChanged
        }
        return event
    }

    private func findCalendar(_ id: String?) throws -> EKCalendar {
        guard let id else { throw StoreError.noWritableCalendar }
        guard let calendar = store.calendar(withIdentifier: id), calendar.allowsContentModifications else {
            throw StoreError.calendarUnavailable
        }
        return calendar
    }

    private func requireAccess() throws {
        guard defaults != nil, EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            refresh()
            throw StoreError.accessRequired
        }
    }

    private func validate(_ draft: CalendarEvent, original: CalendarEvent?) throws {
        let hadNoDuration = original.map { !$0.isAllDay && $0.start == $0.end } ?? false
        let keepNoDuration = hadNoDuration && !draft.isAllDay && draft.start == draft.end
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (draft.end <= draft.start && !keepNoDuration) {
            throw StoreError.invalidEvent
        }
    }

    private func eventReference(_ event: EKEvent) -> CalendarEvent.AppleOccurrence? {
        guard let id = event.eventIdentifier, let calendar = event.calendar,
              let start = event.startDate else { return nil }
        return .init(calendarID: calendar.calendarIdentifier, eventID: id, start: start,
            occurrenceDate: event.hasRecurrenceRules || event.isDetached ? event.occurrenceDate : nil)
    }

    private func makeEvent(_ event: EKEvent) -> CalendarEvent? {
        guard let calendar = event.calendar, let rawEnd = event.endDate,
              let reference = eventReference(event) else { return nil }

        var end = rawEnd
        if event.isAllDay {
            let cal = Calendar.current
            if rawEnd <= reference.start || cal.startOfDay(for: rawEnd) != rawEnd {
                end = cal.dateInterval(of: .day, for: max(reference.start, rawEnd))?.end ?? rawEnd
            }
        }

        let title = event.title ?? ""
        var result = CalendarEvent(
            title: title.isEmpty ? "Untitled Event" : title,
            start: reference.start, end: end,
            location: event.location ?? "", notes: event.notes ?? "",
            calendar: calendar.title,
            color: colors[reference.colorKey].map { Color($0) } ?? calendarColor(calendar)
        )
        result.appleOccurrence = reference
        result.targetCalendarID = reference.calendarID
        result.lastModified = event.lastModifiedDate
        result.isEditable = calendar.allowsContentModifications
        result.isRecurring = event.hasRecurrenceRules || event.isDetached
        result.isAllDay = event.isAllDay
        return result
    }

    private func calendarColor(_ calendar: EKCalendar) -> Color {
        calendar.cgColor.map { Color(cgColor: $0) } ?? .purple
    }

    private func saveLocalEvents() {
        if let data = try? JSONEncoder().encode(localEvents) {
            defaults?.set(data, forKey: "calendarEvents")
        }
    }

    private func saveColors() {
        if let data = try? JSONEncoder().encode(colors) {
            defaults?.set(data, forKey: "appleCalendarEventColors")
        }
    }
}

private enum StoreError: LocalizedError {
    case accessRequired, noWritableCalendar, calendarUnavailable, readOnly
    case eventUnavailable, eventChanged, invalidEvent

    var errorDescription: String? {
        switch self {
        case .accessRequired: return "Allow Full Access to Calendars in Settings to change Apple Calendar events."
        case .noWritableCalendar: return "Create a calendar in Apple Calendar before adding events."
        case .calendarUnavailable: return "That calendar is no longer available for editing. Choose another calendar."
        case .readOnly: return "This calendar is read-only."
        case .eventUnavailable: return "This event was moved or removed from Apple Calendar."
        case .eventChanged: return "This event changed in Apple Calendar. Close the editor and reopen it to see the latest details."
        case .invalidEvent: return "Enter a title and a valid end date."
        }
    }
}

// hello is this proof that i did it idk, i changed most of the code
