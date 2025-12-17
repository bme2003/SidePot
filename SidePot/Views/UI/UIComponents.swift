//
//  UIComponents.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.vertical, 6)
    }
}
