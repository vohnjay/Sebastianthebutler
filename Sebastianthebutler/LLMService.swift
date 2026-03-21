//
//  LLMService.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import Foundation

// MARK: - Request / Response types

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

struct OllamaChatStreamChunk: Codable {
    struct MessageContent: Codable {
        let role: String?
        let content: String
    }
    let message: MessageContent?
    let done: Bool
}

struct OllamaTagsResponse: Codable {
    struct OllamaModel: Codable {
        let name: String
    }
    let models: [OllamaModel]
}

// MARK: - Service

struct LLMService {
    static let shared = LLMService()

    /// Fetches the list of locally available models from an Ollama server.
    func fetchModels(serverURL: String) async throws -> [String] {
        guard let url = URL(string: "\(serverURL)/api/tags") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return response.models.map { $0.name }
    }

    /// Streams a chat response from Ollama, yielding text chunks as they arrive.
    func streamChat(
        messages: [OllamaMessage],
        model: String,
        serverURL: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: "\(serverURL)/api/chat") else {
                        continuation.finish(throwing: URLError(.badURL))
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(
                        OllamaChatRequest(model: model, messages: messages, stream: true)
                    )

                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    for try await line in bytes.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(OllamaChatStreamChunk.self, from: data)
                        else { continue }

                        if let content = chunk.message?.content, !content.isEmpty {
                            continuation.yield(content)
                        }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
