//
//  SheetView.swift
//  calendarreimagined
//
//  Created by Joseph Kevin Fredric on 14/11/26.
//

import SwiftUI

struct SheetView: View {
    @Environment(\.calendar) private var calendar

    let selectedDate: Date
    let store: EventStore
    let onAdd: (CalendarEvent) -> Void

    var body: some View {
        EventDetailEditor(event: newEvent, store: store, isNew: true) { draft in
            onAdd(try store.add(draft))
        }
    }

    private var newEvent: CalendarEvent {
        let now = Date.now
        let start: Date

        if calendar.isDate(now, inSameDayAs: selectedDate) {
            start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        } else {
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        }

        let target = store.writableCalendars.first { $0.id == store.defaultCalendarID }
        var event = CalendarEvent(
            title: "",
            start: start,
            end: start.addingTimeInterval(3600),
            location: "",
            notes: "",
            calendar: target?.title ?? "",
            color: target?.color ?? .purple
        )
        event.targetCalendarID = target?.id
        return event
    }
}

#Preview {
    SheetView(selectedDate: .now, store: EventStore(defaults: nil)) { _ in }
}
