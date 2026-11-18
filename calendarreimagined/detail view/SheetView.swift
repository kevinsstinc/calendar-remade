//
//  SheetView.swift
//  calendarreimagined
//
//  Created by Joseph Kevin Fredric on 14/11/26.
//

import EventKit
import SwiftUI

struct SheetView: View {
    @Environment(\.calendar) private var calendar

    let selectedDate: Date
    let store: EventStore
    let onAdd: (CalendarEvent) -> Void

    var body: some View {
        let now = Date.now
        let start: Date

        if calendar.isDate(now, inSameDayAs: selectedDate) {
            start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        } else {
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        }

        let target = store.defaultCalendar
        var event = CalendarEvent(
            title: "",
            start: start,
            end: start.addingTimeInterval(3600),
            location: "",
            notes: "",
            calendar: target?.title ?? "",
            color: target?.eventColor ?? .purple
        )
        event.targetCalendarID = target?.calendarIdentifier

        return EventDetailEditor(event: event, store: store, isNew: true) { draft in
            onAdd(try store.add(draft))
        }
    }
}

#Preview {
    SheetView(selectedDate: .now, store: EventStore(defaults: nil)) { _ in }
}
