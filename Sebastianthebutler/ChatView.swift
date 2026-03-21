//
//  ChatView.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

// MARK: - Suggested Prompts

struct SuggestedPrompt: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let prompt: String
}

let suggestedPrompts: [SuggestedPrompt] = [
    SuggestedPrompt(emoji: "🔭", label: "Science",    prompt: "Why is the sky blue?"),
    SuggestedPrompt(emoji: "📜", label: "History",    prompt: "Tell me about the first moon landing"),
    SuggestedPrompt(emoji: "🔢", label: "Math",       prompt: "What makes pi so special?"),
    SuggestedPrompt(emoji: "💻", label: "Coding",     prompt: "What is an algorithm? Explain it simply"),
    SuggestedPrompt(emoji: "🧠", label: "Mind",       prompt: "How do dreams actually work?"),
    SuggestedPrompt(emoji: "⚡️", label: "Physics",    prompt: "How does electricity work?"),
    SuggestedPrompt(emoji: "🌍", label: "Geography",  prompt: "Why do earthquakes happen?"),
    SuggestedPrompt(emoji: "🤖", label: "AI",         prompt: "Explain artificial intelligence like I'm 12"),
]

// MARK: - Main Chat View

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var conversation: Conversation
    @Query private var allMessages: [Message]

    @State private var viewModel = ChatViewModel()
    @State private var showSettings = false

    // Filter messages for this conversation only
    private var messages: [Message] {
        allMessages
            .filter { $0.conversation?.id == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if let error = viewModel.errorMessage { errorBanner(error) }
            inputBar
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty && !viewModel.isLoading {
                        welcomeCard
                    }
                    ForEach(messages) { message in
                        MessageBubble(message: message).id(message.id)
                    }
                    if !viewModel.streamingResponse.isEmpty {
                        StreamingBubble(text: viewModel.streamingResponse)
                    } else if viewModel.isLoading {
                        TypingIndicator()
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: viewModel.streamingResponse) { _, _ in scrollToBottom(proxy) }
        }
    }

    // MARK: - Welcome card with suggested prompts

    private var welcomeCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 32)

                Text("Hey! I'm Sebastian 👋")
                    .font(.title2.bold())

                Text("Your personal learning companion. Ask me anything — or pick a topic below to get started!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if viewModel.selectedModel.isEmpty {
                    Label("Tap ⚙️ to connect a model first", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            // Suggested prompts grid
            promptGrid
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: 500)
    }

    private var promptGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(suggestedPrompts) { p in
                Button {
                    viewModel.inputText = p.prompt
                    sendMessage()
                } label: {
                    HStack(spacing: 10) {
                        Text(p.emoji)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(p.prompt)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedModel.isEmpty || viewModel.isLoading)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask me anything...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .submitLabel(.send)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: viewModel.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(canSend ? .tint : .secondary)
            }
            .disabled(!canSend && !viewModel.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark")
            Text(message).font(.caption)
            Spacer()
            Button("Dismiss") { viewModel.errorMessage = nil }
                .font(.caption.bold())
        }
        .padding(10)
        .foregroundStyle(.white)
        .background(.red.gradient)
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.selectedModel.isEmpty
    }

    private func sendMessage() {
        Task {
            await viewModel.sendMessage(
                messages: messages,
                conversation: conversation,
                modelContext: modelContext
            )
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message

    private var isUser: Bool { message.messageRole == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }
            if !isUser { avatar }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                        ? AnyShapeStyle(.tint.gradient)
                        : AnyShapeStyle(Color(.secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .foregroundStyle(isUser ? .white : .primary)
                .textSelection(.enabled)

            if isUser { userAvatar } else { Spacer(minLength: 50) }
        }
    }

    private var avatar: some View {
        Circle()
            .fill(.tint.gradient)
            .frame(width: 30, height: 30)
            .overlay {
                Text("S")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    private var userAvatar: some View {
        Circle()
            .fill(.secondary.opacity(0.4))
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Streaming Bubble

struct StreamingBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(.tint.gradient)
                .frame(width: 30, height: 30)
                .overlay {
                    Text("S")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

            Text(text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.primary)

            Spacer(minLength: 50)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var bounce = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(.tint.gradient)
                .frame(width: 30, height: 30)
                .overlay {
                    Text("S")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .offset(y: bounce ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: bounce
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 50)
        }
        .onAppear { bounce = true }
    }
}
