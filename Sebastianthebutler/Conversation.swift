//
//  Conversation.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
    }

    /// Auto-title from the first user message, truncated to ~40 chars.
    func autoTitle(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        title = trimmed.count > 40
            ? String(trimmed.prefix(37)) + "…"
            : trimmed
    }
}
