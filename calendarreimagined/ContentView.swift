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

    var body: some View {
        HStack(spacing: 0) {

            SideView()
                .frame(width: 95)

            ScrollView {
                VStack(alignment: .leading, spacing: 45) {

                    ForEach(0..<((events.count + 1) / 2), id: \.self) { pair in

                        VStack(alignment: .leading, spacing: 15) {

                            ForEach(
                                (pair * 2)..<min(pair * 2 + 2, events.count),
                                id: \.self
                            ) { i in

                                event(
                                    color: events[i].color,
                                    title: events[i].title,
                                    time: events[i].time,
                                    place: events[i].place
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .padding(.trailing, 20)
                .padding(.bottom, 90)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .overlay(alignment: .bottomTrailing) {
            Button {
                //placeholder for now
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
            .padding(.bottom, -6)
        }
    }
}

#Preview {
    ContentView()
}
