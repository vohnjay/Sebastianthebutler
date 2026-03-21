//
//  ContentView.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationSplitView {
            ConversationListView(selectedConversation: $selectedConversation)
        } detail: {
            if let conversation = selectedConversation {
                ChatView(conversation: conversation)
                    // Re-create the ChatView when conversation changes so state is fresh
                    .id(conversation.id)
            } else {
                NoChatSelectedView(onNew: startNewConversation)
            }
        }
    }

    private func startNewConversation() {
        let c = Conversation()
        modelContext.insert(c)
        selectedConversation = c
    }
}

// MARK: - Placeholder when nothing is selected

struct NoChatSelectedView: View {
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("Welcome to Sebastian")
                .font(.largeTitle.bold())

            Text("Your personal learning companion.\nPick a conversation or start a new one.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onNew) {
                Label("New Conversation", systemImage: "square.and.pencil")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.tint.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
