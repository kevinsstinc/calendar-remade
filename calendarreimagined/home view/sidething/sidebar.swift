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

    let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

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
                                DateCard(
                                    day: days[i],
                                    date: "\(14 + i)",
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

                                    let i = min(6, max(0,
                                        Int(value.location.y / rowHeight)
                                    ))

                                    if selected != i {
                                        withAnimation(.spring(response: 0.3)) {
                                            selected = i
                                        }
                                    }
                                }
                        )
                    }
                }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SideView()
}


