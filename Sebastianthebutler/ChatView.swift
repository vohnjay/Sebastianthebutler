//
//  ChatView.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import SwiftUI
import SwiftData

// MARK: - Main Chat View

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Message.timestamp) private var messages: [Message]

    @State private var viewModel = ChatViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if let error = viewModel.errorMessage { errorBanner(error) }
                inputBar
            }
            .navigationTitle("Sebastian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { clearConversation() } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
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
    }

    // MARK: - Subviews

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

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
                .padding(.top, 40)

            Text("Hey! I'm Sebastian 👋")
                .font(.title2.bold())

            Text("Your personal learning companion. Ask me anything — science, history, math, coding, or whatever you're curious about. Let's explore together!")
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
        .padding(28)
        .frame(maxWidth: 380)
    }

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
        Task { await viewModel.sendMessage(messages: messages, modelContext: modelContext) }
    }

    private func clearConversation() {
        messages.forEach { modelContext.delete($0) }
        viewModel.streamingResponse = ""
        viewModel.errorMessage = nil
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

// MARK: - Streaming Bubble (live response)

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

// MARK: - Preview

#Preview {
    ChatView()
        .modelContainer(for: Message.self, inMemory: true)
}
