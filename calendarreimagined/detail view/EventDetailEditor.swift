//
//  EventDetailEditor.swift
//  calendarreimagined
//
//  Created by Joseph Kevin Fredric on 15/11/26.
//

import SwiftUI

struct EventDetailEditor: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CalendarEvent
    @State private var saveError = ""
    @State private var showingSaveError = false
    @State private var hasChosenColor = false

    private let original: CalendarEvent
    private let store: EventStore
    private let isNew: Bool
    private let onSave: (CalendarEvent) throws -> Void

    init(
        event: CalendarEvent,
        store: EventStore,
        isNew: Bool = false,
        onSave: @escaping (CalendarEvent) throws -> Void
    ) {
        _draft = State(initialValue: event)
        self.original = event
        self.store = store
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        let calendars = store.writableCalendars

        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                    TextField("Location", text: $draft.location)
                }

                Section("Date & Time") {
                    Toggle("All-day", isOn: allDayBinding)

                    DatePicker(
                        "Starts",
                        selection: startBinding,
                        displayedComponents: dateComponents
                    )

                    DatePicker(
                        "Ends",
                        selection: endBinding,
                        in: startBinding.wrappedValue...,
                        displayedComponents: dateComponents
                    )
                }

                Section("Calendar") {
                    if isNew || original.isAppleCalendarEvent {
                        Picker("Calendar", selection: $draft.targetCalendarID) {
                            if let id = draft.targetCalendarID {
                                if !calendars.contains(where: { $0.id == id }) {
                                    Text(draft.calendar).tag(Optional(id))
                                }
                            } else {
                                Text(calendars.isEmpty ? "No Writable Calendars" : "Choose Calendar")
                                    .tag(nil as String?)
                            }

                            ForEach(calendars) { option in
                                Text(option.source.isEmpty ? option.title : "\(option.title) (\(option.source))")
                                    .tag(Optional(option.id))
                            }
                        }
                        .onChange(of: draft.targetCalendarID) { _, id in
                            if isNew, !hasChosenColor,
                               let selected = calendars.first(where: { $0.id == id }) {
                                draft.color = selected.color
                            }
                        }
                    } else {
                        TextField("Calendar", text: $draft.calendar)
                    }

                    ColorPicker(
                        "Event Colour",
                        selection: colorBinding,
                        supportsOpacity: false
                    )
                }

                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle(isNew ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        if isNew {
                            Image(systemName: "xmark")
                        } else {
                            Text("Cancel")
                        }
                    }
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isNew {
                            Image(systemName: "checkmark")
                        } else {
                            Text("Save")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityLabel(isNew ? "Add Event" : "Save")
                }
            }
            .alert("Couldn’t Save Event", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError)
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { draft.color },
            set: { color in
                let oldColor = draft.resolvedColor
                draft.color = color
                if draft.resolvedColor != oldColor {
                    hasChosenColor = true
                }
            }
        )
    }

    private var dateComponents: DatePickerComponents {
        draft.isAllDay ? .date : [.date, .hourAndMinute]
    }

    private var canSave: Bool {
        let hasTitle = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDuration = draft.end > draft.start || (allowsZeroDuration && draft.start == draft.end)
        return hasTitle && hasDuration
    }

    private var allowsZeroDuration: Bool {
        !isNew && !draft.isAllDay && original.start == original.end
    }

    private var lastAllDayDate: Date {
        calendar.startOfDay(for: max(draft.start, draft.end.addingTimeInterval(-1)))
    }

    private var allDayBinding: Binding<Bool> {
        Binding(
            get: { draft.isAllDay },
            set: { isAllDay in
                guard draft.isAllDay != isAllDay else { return }

                let lastDay = lastAllDayDate
                if isAllDay {
                    draft.start = calendar.startOfDay(for: draft.start)
                    draft.end = nextDay(after: lastDay)
                } else {
                    draft.start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: draft.start) ?? draft.start
                    draft.end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: lastDay)
                        ?? draft.start.addingTimeInterval(3600)
                }
                draft.isAllDay = isAllDay
            }
        )
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { draft.isAllDay ? calendar.startOfDay(for: draft.start) : draft.start },
            set: { newStart in
                if draft.isAllDay {
                    // Count calendar days at noon because some time zones skip midnight.
                    let first = noon(on: draft.start)
                    let last = noon(on: lastAllDayDate)
                    let offset = calendar.dateComponents([.day], from: first, to: last).day ?? 0
                    let start = calendar.startOfDay(for: newStart)
                    let lastDay = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                    draft.start = start
                    draft.end = nextDay(after: lastDay)
                } else {
                    let duration = draft.end.timeIntervalSince(draft.start)
                    draft.start = newStart
                    draft.end = newStart.addingTimeInterval(max(allowsZeroDuration ? 0 : 60, duration))
                }
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { draft.isAllDay ? lastAllDayDate : draft.end },
            set: { draft.end = draft.isAllDay ? nextDay(after: $0) : $0 }
        )
    }

    private func noon(on date: Date) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    private func nextDay(after date: Date) -> Date {
        calendar.dateInterval(of: .day, for: date)?.end ?? date.addingTimeInterval(86_400)
    }

    private func save() {
        guard canSave else { return }

        var event = draft
        if isNew || event.title != original.title {
            event.title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if isNew || event.location != original.location {
            event.location = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !isNew && !original.isAppleCalendarEvent {
            event.calendar = event.calendar.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        do {
            try onSave(event)
            dismiss()
        } catch {
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}
