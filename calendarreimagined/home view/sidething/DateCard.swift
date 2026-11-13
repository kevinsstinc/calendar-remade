//
//  DateCard.swift
//  MyApp
//
//  Created by Joseph Kevin Fredric on 13/11/26.
//
import SwiftUI

struct DateCard: View {
    var day: String
    var date: String
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: -6) {
            Text(day)
                .tracking(3)
                .font(.system(size: 14))

            Text(date)
                .tracking(-3)
                .font(.system(size: 42))
        }
        .foregroundStyle(isSelected ? .black : .white)
    }
}

#Preview {
    DateCard(day: "MON", date: "14")
}
