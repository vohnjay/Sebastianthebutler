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

    @Binding var selection: AppDestination?

    var body: some View {
        List(selection: $selection) {
            // ── Daily Briefing row ──────────────────────────────────
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red:1,green:0.85,blue:0.4),
                                             Color(red:1,green:0.65,blue:0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                            )
                            .frame(width: 36, height: 36)
                        Image(systemName: "sun.horizon.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Briefing")
                            .font(.headline)
                        Text("Weather · Events · Reminders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .tag(AppDestination.dailyBriefing)
            }

            // ── Conversations ───────────────────────────────────────
            Section {
                ForEach(conversations) { conversation in
                    ConversationRow(conversation: conversation)
                        .tag(AppDestination.conversation(conversation))
                }
                .onDelete(perform: deleteConversations)
            } header: {
                Text("Conversations")
            }
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
                emptyConversationsHint
            }
        }
    }

    // MARK: – Empty hint

    private var emptyConversationsHint: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No conversations yet")
                .font(.subheadline.weight(.medium))
            Text("Tap ✏️ to start chatting with Sebastian.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    // MARK: – Actions

    private func newConversation() {
        let c = Conversation()
        modelContext.insert(c)
        selection = .conversation(c)
    }

    private func deleteConversations(at offsets: IndexSet) {
        for i in offsets {
            let c = conversations[i]
            if selection == .conversation(c) { selection = nil }
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
            .first
            .map { String($0.content.prefix(60)) }
            ?? "No messages yet"
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
