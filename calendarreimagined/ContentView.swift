//hello guys


import SwiftUI

struct ContentView: View {

    let events: [(color: Color, title: String, time: String, place: String)] = [
        (.purple, "Study English", "7:30AM → 8:30AM", "Home"),
        (.blue, "Physics Revision", "9:00AM → 10:30AM", "Library"),
        (.orange, "Breakfast", "10:30AM → 11:00AM", "Cafe"),
        (.green, "Project Development", "11:00AM → 12:30PM", "Workspace"),
        (.pink, "Team Meeting", "1:00PM → 2:00PM", "Conference Room"),
        (.indigo, "Mathematics", "2:30PM → 3:30PM", "Study Room"),
        (.mint, "Take a Break", "3:30PM → 4:00PM", "Home"),
        (.cyan, "Chemistry Revision", "4:00PM → 5:30PM", "Library"),
        (.yellow, "Dinner", "6:00PM → 7:00PM", "Restaurant"),
        (.red, "Gym", "7:30PM → 8:30PM", "ActiveSG"),
        (.teal, "Coding Session", "9:00PM → 10:00PM", "Home"),
        (.gray, "Plan Tomorrow", "10:00PM → 10:15PM", "Home")
    ]

    @State private var showingSheet = false
    @Namespace private var eventZoom

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                SideView()
                    .frame(width: 95)

                eventList
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .sheet(isPresented: $showingSheet) {
                EmptyView()
                // SheetView()
            }
        }
    }

    // MARK: - Event List

    private var eventList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 45) {
                ForEach(0..<((events.count + 1) / 2), id: \.self) { pair in
                    eventPair(pair)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .padding(.trailing, 20)
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    private func eventPair(_ pair: Int) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(
                (pair * 2)..<min(pair * 2 + 2, events.count),
                id: \.self
            ) { i in
                eventRow(i)
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(_ i: Int) -> some View {
        NavigationLink {
            EventDetailView(event: calendarEvent(at: i))
                .toolbar(.visible, for: .navigationBar)
                .navigationTransition(
                    .zoom(sourceID: i, in: eventZoom)
                )
        } label: {
            event(
                color: events[i].color,
                title: events[i].title,
                time: events[i].time,
                place: events[i].place
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .matchedTransitionSource(id: i, in: eventZoom)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            showingSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
        }
        .glassEffect(
            .regular
                .tint(.purple.opacity(0.65))
                .interactive(),
            in: .circle
        )
        .padding(.trailing, 24)
        .padding(.bottom, -8)
    }

    // MARK: - Event Conversion

    private func calendarEvent(at index: Int) -> CalendarEvent {
        let item = events[index]
        let times = item.time.components(separatedBy: "→")

        return CalendarEvent(
            title: item.title,
            start: parseTime(times.first ?? ""),
            end: parseTime(times.last ?? ""),
            location: item.place,
            notes: "",
            calendar: "Personal",
            color: item.color
        )
    }

    private func parseTime(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let time = formatter.date(
            from: value.trimmingCharacters(in: .whitespaces)
        ) else {
            return .now
        }

        let parts = Calendar.current.dateComponents(
            [.hour, .minute],
            from: time
        )

        return Calendar.current.date(
            bySettingHour: parts.hour ?? 0,
            minute: parts.minute ?? 0,
            second: 0,
            of: .now
        ) ?? .now
    }
}

#Preview {
    ContentView()
}
