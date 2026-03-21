//
//  Message.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
}

@Model
final class Message {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role.rawValue
        self.content = content
        self.timestamp = Date()
    }

    var messageRole: MessageRole {
        MessageRole(rawValue: role) ?? .user
    }
}
