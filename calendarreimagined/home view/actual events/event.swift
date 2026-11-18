//
//  event.swift
//  calendarreimagined
//
//  Created by Joseph Kevin Fredric on 13/11/26.
//

import SwiftUI

struct EventRow: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(event.color)
                .opacity(0.5)
                .frame(width: 13, height: 35)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.system(size: 20))
                    .fontWeight(.medium)

                Text(summary)
                    .font(.system(size: 11))
                    .tracking(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var summary: String {
        let time = event.isAllDay ? String(localized: "All-day") : timeRange
        return event.location.isEmpty ? time : "\(time), \(event.location)"
    }

    private var timeRange: String {
        var format = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .hour().minute()
        if !calendar.isDate(event.start, inSameDayAs: event.end) {
            format = format.month(.abbreviated).day()
        }
        return "\(event.start.formatted(format)) → \(event.end.formatted(format))"
    }
}

#Preview {
    EventRow(event: .sample)
}
