//
//  sidebar.swift
//  MyApp
//
//  Created by Joseph Kevin Fredric on 13/11/26.
//

import SwiftUI

struct SideView: View {
    @Binding var selectedDate: Date
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @State private var selectionBeforeDrag: Date?
    @GestureState private var isDragging = false
    @Namespace private var glass

    private var week: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        Rectangle()
            .fill(.black)
            .frame(width: 95)
            .ignoresSafeArea()
            .overlay {
                GeometryReader { geometry in
                    let days = week
                    let rowHeight = geometry.size.height / CGFloat(max(1, days.count))

                    VStack(spacing: 0) {
                        ForEach(days, id: \.self) { date in
                            dayCard(for: date, rowHeight: rowHeight)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(dateGesture(days: days, rowHeight: rowHeight))
                }
            }
            .frame(maxHeight: .infinity)
            .onChange(of: isDragging) { _, active in
                if !active { selectionBeforeDrag = nil }
            }
    }

    private func dayCard(for date: Date, rowHeight: CGFloat) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let format = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)

        return DateCard(
            day: date.formatted(format.weekday(.abbreviated)).uppercased(with: locale),
            date: date.formatted(format.day()),
            isSelected: isSelected
        )
        .scaleEffect(min(1, rowHeight / 70))
        .frame(width: 70, height: min(100, rowHeight))
        .background {
            if isSelected {
                Color.clear
                    .glassEffect(.regular.tint(.white.opacity(0.7)), in: .rect(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    }
                    .matchedGeometryEffect(id: "glass", in: glass)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(format.weekday(.wide).month(.wide).day().year()))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(date) }
        .accessibilityAction(named: Text("Previous Week")) { changeWeek(by: -1, from: selectedDate) }
        .accessibilityAction(named: Text("Next Week")) { changeWeek(by: 1, from: selectedDate) }
    }

    private func dateGesture(days: [Date], rowHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, active, _ in active = true }
            .onChanged { value in
                if selectionBeforeDrag == nil {
                    selectionBeforeDrag = selectedDate
                }
                guard rowHeight > 0, !days.isEmpty,
                      abs(value.translation.height) >= abs(value.translation.width) else { return }
                let index = min(days.count - 1, max(0, Int(value.location.y / rowHeight)))
                select(days[index])
            }
            .onEnded { value in
                let start = selectionBeforeDrag ?? selectedDate
                selectionBeforeDrag = nil
                let horizontal = value.translation.width
                guard abs(horizontal) >= 36,
                      abs(horizontal) > abs(value.translation.height) else { return }
                changeWeek(by: horizontal < 0 ? 1 : -1, from: start)
            }
    }

    private func changeWeek(by offset: Int, from date: Date) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: offset, to: date) {
            select(newDate)
        }
    }

    private func select(_ date: Date) {
        guard !calendar.isDate(date, inSameDayAs: selectedDate) else { return }
        withAnimation(.spring(response: 0.3)) {
            selectedDate = calendar.startOfDay(for: date)
        }
    }
}

#Preview {
    @Previewable @State var selectedDate = Date.now
    SideView(selectedDate: $selectedDate)
}
