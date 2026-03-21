//
//  ContentView.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

// MARK: - Sidebar selection

enum AppDestination: Hashable {
    case dailyBriefing
    case conversation(Conversation)
}

// MARK: - Root view

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppDestination?

    var body: some View {
        NavigationSplitView {
            ConversationListView(selection: $selection)
        } detail: {
            switch selection {
            case .dailyBriefing:
                DailyBriefingView()
            case .conversation(let c):
                ChatView(conversation: c).id(c.id)
            case nil:
                NoSelectionView(onNewConversation: startNewConversation,
                                onBriefing: { selection = .dailyBriefing })
            }
        }
    }

    private func startNewConversation() {
        let c = Conversation()
        modelContext.insert(c)
        selection = .conversation(c)
    }
}

// MARK: - Nothing selected placeholder

struct NoSelectionView: View {
    let onNewConversation: () -> Void
    let onBriefing: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Welcome to Sebastian")
                    .font(.largeTitle.bold())
                Text("Your personal learning companion and daily butler.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: onBriefing) {
                    Label("Today's Daily Briefing", systemImage: "sun.horizon.fill")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color(red:1,green:0.93,blue:0.7),
                                         Color(red:1,green:0.80,blue:0.55)],
                                startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 0.0))
                }
                .buttonStyle(.plain)

                Button(action: onNewConversation) {
                    Label("New Conversation", systemImage: "square.and.pencil")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 13)
                        .background(.tint.gradient, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
}
