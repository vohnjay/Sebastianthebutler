//
//  ChatViewModel.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import Foundation
import SwiftData
import Observation

@Observable
final class ChatViewModel {

    // MARK: - UI State
    var inputText: String = ""
    var streamingResponse: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var availableModels: [String] = []
    var isFetchingModels: Bool = false

    // MARK: - Persisted Settings
    var serverURL: String = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:11434" {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    var selectedModel: String = UserDefaults.standard.string(forKey: "selectedModel") ?? "" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }

    // MARK: - Sebastian's Personality

    static let systemPrompt = """
    You are Sebastian, a knowledgeable and enthusiastic learning companion created to educate \
    and inspire the next generation. Think of yourself as that brilliant older sibling or mentor \
    who makes learning feel exciting rather than like homework.

    Your personality:
    • Warm, approachable, and genuinely excited about every subject
    • Patient and never condescending — you meet learners exactly where they are
    • You explain complex topics using clear language, relatable examples, and real-world connections
    • You celebrate curiosity — every question is a great question
    • You use light, appropriate humor to keep things engaging and fun
    • You break down big ideas into digestible, memorable pieces
    • You spark critical thinking by occasionally asking "What do you think?" or \
    "Why do you think that works that way?"
    • You use "we" language to make learning feel collaborative: "Let's figure this out together"
    • Keep responses focused and readable — no walls of text, no information overload
    • Use the occasional emoji to add warmth 🌟, but keep it natural

    Your goal is never just to answer — it's to spark curiosity and leave the learner hungry \
    to explore more. Every response should feel like an exciting step in a journey, \
    not the end of the road.
    """

    // MARK: - Private

    private let service = LLMService.shared

    // MARK: - Actions

    func sendMessage(messages: [Message], modelContext: ModelContext) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !selectedModel.isEmpty else { return }

        inputText = ""
        isLoading = true
        errorMessage = nil

        let userMessage = Message(role: .user, content: text)
        modelContext.insert(userMessage)

        // Build context window: system prompt + last 20 turns + new user message
        var apiMessages: [OllamaMessage] = [
            OllamaMessage(role: "system", content: Self.systemPrompt)
        ]
        let history = messages.sorted(by: { $0.timestamp < $1.timestamp }).suffix(20)
        apiMessages += history.map { OllamaMessage(role: $0.role, content: $0.content) }
        apiMessages.append(OllamaMessage(role: "user", content: text))

        streamingResponse = ""

        do {
            let stream = service.streamChat(messages: apiMessages, model: selectedModel, serverURL: serverURL)
            for try await chunk in stream {
                streamingResponse += chunk
            }
            if !streamingResponse.isEmpty {
                let assistantMessage = Message(role: .assistant, content: streamingResponse)
                modelContext.insert(assistantMessage)
            }
            streamingResponse = ""
        } catch {
            errorMessage = "Couldn't reach the model. Check your server settings ⚙️"
        }

        isLoading = false
    }

    func fetchModels() async {
        isFetchingModels = true
        defer { isFetchingModels = false }
        do {
            availableModels = try await service.fetchModels(serverURL: serverURL)
            if !availableModels.isEmpty && selectedModel.isEmpty {
                selectedModel = availableModels[0]
            }
        } catch {
            availableModels = []
        }
    }
}
