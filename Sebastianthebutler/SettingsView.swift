//
//  SettingsView.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ChatViewModel
    @AppStorage("userName") private var userName = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Personal Section
                Section {
                    HStack {
                        Label("Your Name", systemImage: "person.fill")
                        Spacer()
                        TextField("e.g. Alex", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Personal")
                } footer: {
                    Text("Sebastian uses your name in the Daily Briefing and greetings.")
                }

                // MARK: Server Section
                Section {
                    HStack {
                        Label("Server URL", systemImage: "server.rack")
                        Spacer()
                        TextField("http://localhost:11434", text: $viewModel.serverURL)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Enter the address of your Ollama server. On the same device, use http://localhost:11434. On a Mac on the same Wi-Fi, use the Mac's local IP (e.g. http://192.168.1.10:11434).")
                }

                // MARK: Model Section
                Section {
                    if viewModel.isFetchingModels {
                        HStack {
                            ProgressView()
                            Text("Fetching models…").foregroundStyle(.secondary)
                        }
                    } else if viewModel.availableModels.isEmpty {
                        Text("No models found — tap Refresh to search.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Active Model", selection: $viewModel.selectedModel) {
                            ForEach(viewModel.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    Button {
                        Task { await viewModel.fetchModels() }
                    } label: {
                        Label("Refresh Model List", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Model")
                } footer: {
                    Text("Models you have pulled with `ollama pull <name>` will appear here.")
                }

                // MARK: Personality Preview
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Sebastian's Teaching Style", systemImage: "graduationcap.fill")
                            .font(.subheadline.bold())
                        Text("""
                            • Warm & encouraging — celebrates curiosity
                            • Clear explanations with relatable examples
                            • Sparks critical thinking with follow-up questions
                            • Collaborative "let's explore together" tone
                            • Focused, readable responses — no information overload
                            """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Personality")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if viewModel.availableModels.isEmpty {
                    await viewModel.fetchModels()
                }
            }
        }
    }
}
