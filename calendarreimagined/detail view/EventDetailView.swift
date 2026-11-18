//
//  EventDetailView.swift
//  calendarreimagined
//
//  Created by Joseph Kevin Fredric on 15/11/26.
//

import SwiftUI
import UIKit

struct EventDetailView: View {
    @Environment(\.calendar) private var calendar

    let event: CalendarEvent
    let store: EventStore
    let onUpdate: (CalendarEvent) -> Void
    let onDelete: () -> Void

    @State private var editingEvent: CalendarEvent?
    @State private var showingDelete = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Event title and time
                VStack(alignment: .leading, spacing: 12) {
                    Text(event.title)
                        .font(.title.weight(.semibold))

                    VStack(alignment: .leading, spacing: 5) {
                        if event.isAllDay {
                            Text(allDayDates(style: .full))

                            Text("All-day")
                                .foregroundStyle(.secondary)
                        } else if calendar.isDate(event.start, inSameDayAs: event.end) {
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

                        if !event.isAllDay, let duration {
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                if event.isEditable {
                    Button {
                        editingEvent = event
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit Event")
                }

                Menu {
                    ShareLink(item: shareText) {
                        Label("Share Event", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIPasteboard.general.string = shareText
                    } label: {
                        Label("Copy Details", systemImage: "doc.on.doc")
                    }

                    if event.isEditable {
                        Button(role: .destructive) {
                            showingDelete = true
                        } label: {
                            Label(deleteTitle, systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More Actions")
            }
        }
        .sheet(item: $editingEvent) { original in
            EventDetailEditor(event: original, store: store) { draft in
                onUpdate(try store.update(draft, basedOn: original))
            }
        }
        .confirmationDialog(deleteQuestion, isPresented: $showingDelete, titleVisibility: .visible) {
            Button(deleteTitle, role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(event.isRecurring
                 ? "Only this occurrence will be removed from your calendar."
                 : "This event will be removed from your calendar.")
        }
        .alert("Couldn’t Delete Event", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var deleteTitle: LocalizedStringKey {
        event.isRecurring ? "Delete This Occurrence" : "Delete Event"
    }

    private var deleteQuestion: LocalizedStringKey {
        event.isRecurring ? "Delete this occurrence?" : "Delete this event?"
    }

    private func delete() {
        do {
            try store.delete(event)
            onDelete()
        } catch {
            deleteError = error.localizedDescription
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
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
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

    private func allDayDates(style: DateIntervalFormatter.Style) -> String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = style
        formatter.timeStyle = .none
        let lastDay = calendar.startOfDay(for: max(event.start, event.end.addingTimeInterval(-1)))
        return formatter.string(from: calendar.startOfDay(for: event.start), to: lastDay)
    }

    private var shareText: String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let date = event.isAllDay
            ? String(localized: "\(allDayDates(style: .medium)) (All-day)")
            : formatter.string(from: event.start, to: event.end)

        return [
            event.title,
            date,
            event.location,
            event.notes
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: .sample, store: EventStore(defaults: nil), onUpdate: { _ in }, onDelete: {})
    }
}
