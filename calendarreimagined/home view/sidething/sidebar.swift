//
//  sidebar.swift
//  MyApp
//
//  Created by Joseph Kevin Fredric on 13/11/26.
//

import SwiftUI

struct SideView: View {
    @State private var selected = 0
    @Namespace private var glass

    private var startOfWeek: Date {
        let cal = Calendar.current
        let now = Date()
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return cal.date(from: components) ?? now
    }

    private func date(for index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index, to: startOfWeek) ?? Date()
    }

    var body: some View {
        HStack(spacing: 0) {

            Rectangle()
                .fill(.black)
                .frame(width: 95)
                .ignoresSafeArea()
                .overlay {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { i in
                                let d = date(for: i)
                                let dayText = DateFormatter.weekdayAbbrev.string(from: d).uppercased()
                                let dateText = DateFormatter.dayNumber.string(from: d)

                                DateCard(
                                    day: dayText,
                                    date: dateText,
                                    isSelected: selected == i
                                )
                                .frame(width: 70, height: 100)
                                .background {
                                    if selected == i {
                                        Color.clear
                                            .glassEffect(
                                                .regular.tint(.white.opacity(0.7)),
                                                in: .rect(cornerRadius: 18)
                                            )
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                                            }
                                            .matchedGeometryEffect(id: "glass", in: glass)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let rowHeight = geo.size.height / 7
                                    guard rowHeight > 0 else { return }

                                    let i = min(6, max(0, Int(value.location.y / rowHeight)))

                                    if selected != i {
                                        withAnimation(.spring(response: 0.3)) {
                                            selected = i
                                        }
                                    }
                                }
                        )
                    }
                }

                .frame(width: 95)
                
        }
        .frame(maxHeight: .infinity)
        .onAppear { selected = Calendar.current.dateComponents([.day], from: startOfWeek, to: Date()).day.map { min(6, max(0, $0)) } ?? 0 }
    }
}

private extension DateFormatter {
    static let dayNumber: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d")
        return f
    }()
    
    static let weekdayAbbrev: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()
}

#Preview {
    SideView()
}
