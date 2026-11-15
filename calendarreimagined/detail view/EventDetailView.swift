//
//  EventDetailView.swift
//  calendarreimagined
//
//  Created by Joseph Kevin Fredric on 15/11/26.
//

import SwiftUI
import UIKit

struct CalendarEvent {
    var title: String
    var start: Date
    var end: Date
    var location: String
    var notes: String
    var calendar: String
    var color: Color

    static var sample: CalendarEvent {
        let start = Calendar.current.date(
            bySettingHour: 7, minute: 30, second: 0, of: .now
        ) ?? .now

        return CalendarEvent(
            title: "Study English",
            start: start,
            end: start.addingTimeInterval(3600),
            location: "Home",
            notes: """
            Complete English Paper 2 practice.

            Focus on comprehension and summary writing.
            Review mistakes from the previous paper.
            """,
            calendar: "Personal",
            color: .purple
        )
    }
}

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var event: CalendarEvent
    @State private var showingEditor = false
    @State private var showingDelete = false

    var onUpdate: ((CalendarEvent) -> Void)?
    var onDelete: (() -> Void)?

    init(
        event: CalendarEvent = .sample,
        onUpdate: ((CalendarEvent) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        _event = State(initialValue: event)
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Event title and time
                    VStack(alignment: .leading, spacing: 12) {
                        Text(event.title)
                            .font(.title.weight(.semibold))

                        VStack(alignment: .leading, spacing: 5) {
                            if Calendar.current.isDate(event.start, inSameDayAs: event.end) {
                                Text(event.start, format: .dateTime
                                    .weekday(.wide).month(.wide).day().year())

                                Text(timeRange)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(event.start, format: .dateTime
                                    .weekday(.abbreviated).month(.abbreviated)
                                    .day().year().hour().minute())

                                Text("to \(formattedEnd)")
                                    .foregroundStyle(.secondary)
                            }

                            if let duration {
                                Text(duration)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 3)
                            }
                        }
                    }

                    // Location
                    if !event.location.isEmpty {
                        detailRow("Location", icon: "mappin.and.ellipse") {
                            Text(event.location)
                                .textSelection(.enabled)
                        }
                    }

                    // Calendar
                    if !event.calendar.isEmpty {
                        detailRow("Calendar", icon: "calendar") {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(event.color)
                                    .frame(width: 9, height: 9)

                                Text(event.calendar)
                            }
                        }
                    }

                    // Notes
                    if !event.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notes")
                                .font(.headline)

                            Text(event.notes)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button {
//                        dismiss()
//                    } label: {
//                        Image(systemName: "xmark")
//                    }
//                    .accessibilityLabel("Close")
//                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit Event")

                    Menu {
                        ShareLink(item: shareText) {
                            Label("Share Event", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            UIPasteboard.general.string = shareText
                        } label: {
                            Label("Copy Details", systemImage: "doc.on.doc")
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                showingDelete = true
                            } label: {
                                Label("Delete Event", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More Actions")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            EventDetailEditor(event: event) { updated in
                event = updated
                onUpdate?(updated)
            }
        }
        .confirmationDialog(
            "Delete this event?",
            isPresented: $showingDelete
        ) {
            Button("Delete Event", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("This event will be removed from your calendar.")
        }
    }

    // Reusable detail row
    private func detailRow<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                content()
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Date formatting
    private var timeRange: String {
        let formatter = DateIntervalFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.start, to: event.end)
    }

    private var formattedEnd: String {
        event.end.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated)
                .day().year().hour().minute()
        )
    }

    private var duration: String? {
        let seconds = event.end.timeIntervalSince(event.start)
        guard seconds >= 60 else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .full
        return formatter.string(from: seconds)
    }

    private var shareText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return [
            event.title,
            formatter.string(from: event.start, to: event.end),
            event.location,
            event.notes
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

// MARK: - Event Editor

private struct EventDetailEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CalendarEvent

    let onSave: (CalendarEvent) -> Void

    init(event: CalendarEvent, onSave: @escaping (CalendarEvent) -> Void) {
        _draft = State(initialValue: event)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                    TextField("Location", text: $draft.location)
                }

                Section("Date & Time") {
                    DatePicker(
                        "Starts",
                        selection: startBinding,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "Ends",
                        selection: $draft.end,
                        in: draft.start...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Calendar") {
                    TextField("Calendar", text: $draft.calendar)

                    ColorPicker(
                        "Event Colour",
                        selection: $draft.color,
                        supportsOpacity: false
                    )
                }

                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.calendar = draft.calendar.trimmingCharacters(in: .whitespacesAndNewlines)

                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        draft.end <= draft.start
                    )
                }
            }
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { draft.start },
            set: { newStart in
                let length = max(60, draft.end.timeIntervalSince(draft.start))
                draft.start = newStart
                draft.end = newStart.addingTimeInterval(length)
            }
        )
    }
}

#Preview {
    EventDetailView()
}
