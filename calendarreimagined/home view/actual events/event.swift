//
//  event.swift
//  calendarreimagined
//
//  Created by Joseph Kevin Fredric on 13/11/26.
//

import SwiftUI

struct event: View {
    var color: Color
    var title: String
    var time: String
    var place: String

    var body: some View {
        ZStack {
            VStack {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(color)
                        .opacity(0.5)
                        .frame(width: 13, height: 35)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 20))
                            .fontWeight(.medium)

                        Text(time + ", " + place)
                            .font(.system(size: 11))
                            .tracking(1)
                            
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#Preview {
    event(
        color: .purple,
        title: "Study English",
        time: "4:00PM – 5:00PM",
        place: "Home"
    )
}


