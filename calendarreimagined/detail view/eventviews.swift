import SwiftUI

struct NewEventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var location = ""
    @State private var start: Date
    @State private var end: Date
    @State private var errorText = ""
    @State private var showingError = false

    let store: EventStore
    let onAdd: (Date) -> Void

    init(date: Date, store: EventStore, onAdd: @escaping (Date) -> Void) {
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        _start = State(initialValue: morning)
        _end = State(initialValue: morning.addingTimeInterval(3600))
        self.store = store
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Event name", text: $title)
                TextField("Location", text: $location)

                DatePicker("Starts", selection: $start)
                DatePicker("Ends", selection: $end, in: start...)
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end <= start)
                }
            }
            .alert("Couldn't add event", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorText)
            }
        }
        .onChange(of: start) { _, newStart in
            if end <= newStart { end = newStart.addingTimeInterval(3600) }
        }
    }

    private func save() {
        do {
            try store.add(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                start: start,
                end: end,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onAdd(start)
            dismiss()
        } catch {
            errorText = error.localizedDescription
            showingError = true
        }
    }
}

