import SwiftUI
import EventKit
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var selectedDate = Date()
    @State private var showingAdd = false

    let store: EventStore

    var body: some View {
        HStack(spacing: 0) {
            SideView(selectedDate: $selectedDate)
                .frame(width: 95)

            VStack(alignment: .leading, spacing: 22) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.title2.bold())
                    .padding(.top, 24)

                if store.permission == .fullAccess {
                    if store.events.isEmpty {
                        Spacer()
                        Text("No events today")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                ForEach(store.events) { event in
                                    HStack(alignment: .top, spacing: 12) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(event.color)
                                            .frame(width: 4)

                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(event.title)
                                                .font(.headline)

                                            Text(event.isAllDay ? "All day" :
                                                "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)

                                            if !event.location.isEmpty {
                                                Text(event.location)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                        }
                        .scrollIndicators(.hidden)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("Calendar access is needed to show events.")
                            .multilineTextAlignment(.center)

                        if store.permission == .denied || store.permission == .restricted {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        } else {
                            Button("Allow Access") {
                                Task {
                                    await store.askForAccess()
                                    store.load(selectedDate)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
        }
        .background(.white)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(.purple, in: Circle())
            }
            .disabled(store.permission != .fullAccess)
            .padding(22)
        }
        .sheet(isPresented: $showingAdd) {
            NewEventView(date: selectedDate, store: store) { date in
                selectedDate = date
                store.load(date)
            }
        }
        .task(id: Calendar.current.startOfDay(for: selectedDate)) {
            await store.askForAccess()
            store.load(selectedDate)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.load(selectedDate) }
        }
    }
}

#Preview {
    ContentView(store: EventStore())
}
