import EventKit
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDate = Date.now
    @State private var showingSheet = false
    @State private var showingCalendarAlert = false
    @State private var requestingCalendarAccess = false
    @State private var calendarAccessError: String?
    @State private var path: [CalendarEvent.ID] = []
    @Namespace private var eventZoom

    let store: EventStore

    var body: some View {
        NavigationStack(path: $path) {
            HStack(spacing: 0) {
                SideView(selectedDate: $selectedDate)
                    .frame(width: 95)

                eventList
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Color.white.ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .navigationDestination(for: CalendarEvent.ID.self) { id in
                EventDestination(store: store, id: id, selectedDate: $selectedDate) {
                    if path.last == id {
                        path.removeLast()
                    }
                }
                .toolbar(.visible, for: .navigationBar)
                .navigationTransition(.zoom(sourceID: id, in: eventZoom))
            }
            .sheet(isPresented: $showingSheet) {
                SheetView(selectedDate: selectedDate, store: store) { event in
                    selectedDate = event.start
                }
            }
            .alert("Calendar Access", isPresented: $showingCalendarAlert) {
                if canRequestCalendarAccess {
                    Button("Allow Calendar Access") {
                        Task { await requestCalendarAccess() }
                    }
                } else if store.authorization == .denied {
                    Button("Open Settings", action: openCalendarSettings)
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(calendarAccessMessage)
            }
        }
        .task {
            store.refresh()
            if store.authorization == .notDetermined {
                await requestCalendarAccess()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refresh()
            }
        }
    }

    private var eventList: some View {
        let events = store.events(on: selectedDate, calendar: calendar)

        return Group {
            if events.isEmpty {
                emptyAgenda
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 45) {
                        ForEach(0..<((events.count + 1) / 2), id: \.self) { pair in
                            VStack(alignment: .leading, spacing: 15) {
                                ForEach(events.dropFirst(pair * 2).prefix(2)) { event in
                                    eventRow(event)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                }
                .scrollIndicators(.hidden)
                .id(calendar.startOfDay(for: selectedDate))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    private var emptyAgenda: some View {
        VStack(spacing: 10) {
            if requestingCalendarAccess {
                ProgressView()
                    .accessibilityLabel("Connecting to Calendar")
            } else if store.authorization == .fullAccess {
                Text("No Events")
                    .accessibilityIdentifier("empty-events")
            } else {
                Text(calendarAccessMessage)

                if canRequestCalendarAccess {
                    Button("Allow Calendar Access") {
                        Task { await requestCalendarAccess() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                } else if store.authorization == .denied {
                    Button("Open Settings", action: openCalendarSettings)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        NavigationLink(value: event.id) {
            EventRow(event: event)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .matchedTransitionSource(id: event.id, in: eventZoom)
                }
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            if store.authorization == .fullAccess && !store.writableCalendars.isEmpty {
                showingSheet = true
            } else {
                showingCalendarAlert = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
        }
        .glassEffect(.regular.tint(.purple.opacity(0.65)).interactive(), in: .circle)
        .accessibilityLabel("New Event")
        .padding(.trailing, 24)
        .padding(.bottom, -8)
    }

    private var canRequestCalendarAccess: Bool {
        store.authorization == .notDetermined || store.authorization == .writeOnly
    }

    private var calendarAccessMessage: String {
        switch store.authorization {
        case .fullAccess:
            return "Create a writable calendar in the Calendar app to add events."
        case .denied:
            return "Allow Full Access to Calendars in Settings to see and manage your events."
        case .restricted:
            return "Calendar access is restricted on this iPhone."
        default:
            return calendarAccessError ?? "Allow Full Access to Calendars to see and manage your events."
        }
    }

    private func requestCalendarAccess() async {
        guard !requestingCalendarAccess else { return }
        requestingCalendarAccess = true
        calendarAccessError = nil
        defer { requestingCalendarAccess = false }

        do {
            try await store.requestCalendarAccess()
        } catch {
            calendarAccessError = error.localizedDescription
        }
    }

    private func openCalendarSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

private struct EventDestination: View {
    @Environment(\.calendar) private var calendar
    @State private var replacementID: CalendarEvent.ID?

    let store: EventStore
    let id: CalendarEvent.ID
    @Binding var selectedDate: Date
    let onDismiss: () -> Void

    var body: some View {
        if let event = store.event(withID: replacementID ?? id) {
            EventDetailView(event: event, store: store, onUpdate: { updated in
                replacementID = updated.id
                if !calendar.isDate(updated.start, inSameDayAs: event.start) {
                    selectedDate = updated.start
                } else if let shownDay = calendar.dateInterval(of: .day, for: selectedDate),
                          !updated.overlaps(shownDay) {
                    selectedDate = updated.start
                }
            }, onDelete: onDismiss)
        } else {
            ContentUnavailableView("Event Unavailable", systemImage: "calendar")
        }
    }
}

#Preview {
    ContentView(store: EventStore(defaults: nil))
}
