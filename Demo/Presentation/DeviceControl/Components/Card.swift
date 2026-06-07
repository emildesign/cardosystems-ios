// Card.swift
import SwiftUI
struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
