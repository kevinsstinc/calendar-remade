
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
            let date = occurrenceDate.map { String($0.timeIntervalSinceReferenceDate) } ?? ""
            return "\(calendarID)/\(eventID)/\(date)"
        }
    }

    private var localID = UUID()
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

    var id: ID {
        if let appleOccurrence {
            return .apple(appleOccurrence)
        }
        return .local(localID)
    }

    var isAppleCalendarEvent: Bool { appleOccurrence != nil }

    var isAllDay: Bool {
        get { allDay ?? false }
        set { allDay = newValue }
    }

    var color: Color {
        get { Color(resolvedColor) }
        set { resolvedColor = newValue.resolve(in: EnvironmentValues()) }
    }

    private enum CodingKeys: String, CodingKey {
        case localID = "id"
        case title, start, end, location, notes, calendar, resolvedColor, allDay
    }

    init(title: String, start: Date, end: Date, location: String, notes: String, calendar: String, color: Color) {
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.notes = notes
        self.calendar = calendar
        self.resolvedColor = color.resolve(in: EnvironmentValues())
    }

    func overlaps(_ interval: DateInterval) -> Bool {
        if start == end {
            return start >= interval.start && start < interval.end
        }
        return start < interval.end && end > interval.start
    }

    static var sample: CalendarEvent {
        samples(on: .now)[0]
    }

    static func samples(on date: Date) -> [CalendarEvent] {
        let items: [(String, Color, Int, Int, Int, String)] = [
            ("Study English", .purple, 7, 30, 60, "Home"),
            ("Physics Revision", .blue, 9, 0, 90, "Library"),
            ("Breakfast", .orange, 10, 30, 30, "Cafe"),
            ("Project Development", .green, 11, 0, 90, "Workspace"),
            ("Team Meeting", .pink, 13, 0, 60, "Conference Room"),
            ("Mathematics", .indigo, 14, 30, 60, "Study Room"),
            ("Take a Break", .mint, 15, 30, 30, "Home"),
            ("Chemistry Revision", .cyan, 16, 0, 90, "Library"),
            ("Dinner", .yellow, 18, 0, 60, "Restaurant"),
            ("Gym", .red, 19, 30, 60, "ActiveSG"),
            ("Coding Session", .teal, 21, 0, 60, "Home"),
            ("Plan Tomorrow", .gray, 22, 0, 15, "Home")
        ]

        return items.map { title, color, hour, minute, duration, location in
            let start = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
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
// hello im back i did this one also
