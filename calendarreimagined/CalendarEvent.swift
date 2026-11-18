import SwiftUI

struct CalendarEvent: Identifiable, Codable {
    enum ID: Hashable {
        case local(UUID)
        case apple(AppleOccurrence)
    }

    struct AppleOccurrence: Hashable {
        let calendarID: String
        let eventID: String
        let start: Date
        let occurrenceDate: Date?

        var colorKey: String {
            let occurrence = occurrenceDate.map { String($0.timeIntervalSinceReferenceDate) } ?? ""
            return "\(calendarID)/\(eventID)/\(occurrence)"
        }
    }

    private var localID = UUID()
    var id: ID { appleOccurrence.map(ID.apple) ?? .local(localID) }

    var title: String
    var start: Date
    var end: Date
    var location: String
    var notes: String
    var calendar: String
    private(set) var resolvedColor: Color.Resolved
    private var allDay: Bool?

    var appleOccurrence: AppleOccurrence?
    var targetCalendarID: String?
    var lastModified: Date?
    var isEditable = true
    var isRecurring = false

    var isAppleCalendarEvent: Bool { appleOccurrence != nil }

    var isAllDay: Bool {
        get { allDay ?? false }
        set { allDay = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case localID = "id"
        case title, start, end, location, notes, calendar, resolvedColor, allDay
    }

    var color: Color {
        get { Color(resolvedColor) }
        set { resolvedColor = newValue.resolve(in: EnvironmentValues()) }
    }

    init(
        title: String,
        start: Date,
        end: Date,
        location: String,
        notes: String,
        calendar: String,
        color: Color
    ) {
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.notes = notes
        self.calendar = calendar
        resolvedColor = color.resolve(in: EnvironmentValues())
    }

    func overlaps(_ interval: DateInterval) -> Bool {
        if start == end {
            return interval.start <= start && start < interval.end
        }
        return start < interval.end && end > interval.start
    }

    static var sample: CalendarEvent {
        samples(on: .now)[0]
    }

    static func samples(on date: Date) -> [CalendarEvent] {
        let day = Calendar.current
        let items: [(Color, String, Int, Int, Int, String)] = [
            (.purple, "Study English", 7, 30, 60, "Home"),
            (.blue, "Physics Revision", 9, 0, 90, "Library"),
            (.orange, "Breakfast", 10, 30, 30, "Cafe"),
            (.green, "Project Development", 11, 0, 90, "Workspace"),
            (.pink, "Team Meeting", 13, 0, 60, "Conference Room"),
            (.indigo, "Mathematics", 14, 30, 60, "Study Room"),
            (.mint, "Take a Break", 15, 30, 30, "Home"),
            (.cyan, "Chemistry Revision", 16, 0, 90, "Library"),
            (.yellow, "Dinner", 18, 0, 60, "Restaurant"),
            (.red, "Gym", 19, 30, 60, "ActiveSG"),
            (.teal, "Coding Session", 21, 0, 60, "Home"),
            (.gray, "Plan Tomorrow", 22, 0, 15, "Home")
        ]

        return items.map { color, title, hour, minute, duration, location in
            let start = day.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
            return CalendarEvent(
                title: title,
                start: start,
                end: start.addingTimeInterval(TimeInterval(duration * 60)),
                location: location,
                notes: "",
                calendar: "Personal",
                color: color
            )
        }
    }
}
