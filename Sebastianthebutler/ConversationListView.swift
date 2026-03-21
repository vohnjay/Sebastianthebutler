//
//  ConversationListView.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]

    @Binding var selectedConversation: Conversation?

    var body: some View {
        List(selection: $selectedConversation) {
            ForEach(conversations) { conversation in
                ConversationRow(conversation: conversation)
                    .tag(conversation)
            }
            .onDelete(perform: deleteConversations)
        }
        .navigationTitle("Sebastian")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: newConversation) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .overlay {
            if conversations.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No conversations yet")
                .font(.headline)
            Text("Tap the pencil icon to start a new one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Actions

    private func newConversation() {
        let c = Conversation()
        modelContext.insert(c)
        selectedConversation = c
    }

    private func deleteConversations(at offsets: IndexSet) {
        for i in offsets {
            let c = conversations[i]
            if selectedConversation?.id == c.id {
                selectedConversation = nil
            }
            modelContext.delete(c)
        }
    }
}

// MARK: - Row

struct ConversationRow: View {
    let conversation: Conversation

    private var subtitle: String {
        conversation.messages
            .sorted { $0.timestamp > $1.timestamp }
            .first?.content
            .prefix(60)
            .description ?? "No messages yet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}
