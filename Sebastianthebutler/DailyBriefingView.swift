//
//  DailyBriefingView.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import SwiftUI
import EventKit

// MARK: - ViewModel

@Observable
final class DailyBriefingViewModel {

    var weather: WeatherData?
    var events: [BriefingEvent] = []
    var reminders: [BriefingReminder] = []
    var isLoading = false
    var weatherError: String?

    let locationManager = LocationManager()
    let eventKit        = EventKitService.shared
    let speech          = SpeechService()

    // Read name from UserDefaults each time (updated by SettingsView)
    var userName: String {
        let stored = UserDefaults.standard.string(forKey: "userName") ?? ""
        return stored.isEmpty ? "there" : stored
    }

    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:      return "Good evening,"
        }
    }

    var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    // MARK: – Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let calReq:  () = eventKit.requestCalendarAccess()
        async let remReq:  () = eventKit.requestReminderAccess()
        _ = try? await (calReq, remReq)

        events    = eventKit.todaysEvents()
        reminders = await eventKit.todaysReminders()

        await fetchWeather()
    }

    private func fetchWeather() async {
        weatherError = nil
        do {
            let coord = try await locationManager.fetchLocation()
            weather = try await WeatherService.shared.fetch(
                latitude:  coord.latitude,
                longitude: coord.longitude
            )
        } catch {
            weatherError = error.localizedDescription
        }
    }

    // MARK: – TTS

    func playBriefing() {
        let script = speech.buildScript(
            name:      userName,
            weather:   weather,
            events:    events,
            reminders: reminders
        )
        speech.speak(script)
    }

    func stopBriefing() { speech.stop() }
}

// MARK: - Main View

struct DailyBriefingView: View {

    @State private var vm = DailyBriefingViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                        .padding(.top, 8)

                    if vm.isLoading {
                        loadingState
                    } else {
                        contentSections
                    }

                    Spacer(minLength: 120)   // room for the play button
                }
                .padding(.horizontal, 20)
            }

            playButton
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .navigationTitle("Daily Briefing")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    // MARK: – Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.97, blue: 0.88),
                Color(red: 1.00, green: 0.93, blue: 0.76),
                Color(red: 1.00, green: 0.88, blue: 0.80),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: – Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // "Playing now" pill
            if vm.speech.isPlaying {
                PlayingNowPill()
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.greeting)
                        .font(.system(size: 38, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                    Text(vm.userName == "there" ? "Friend" : vm.userName)
                        .font(.system(size: 38, weight: .bold, design: .default))
                        .foregroundStyle(.primary)

                    Text(vm.todayLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Text("Your briefing is ready, \(vm.userName == "there" ? "friend" : vm.userName).")
                        .font(.subheadline.italic())
                        .foregroundStyle(Color(red: 0.5, green: 0.4, blue: 0.2))
                        .padding(.top, 2)
                }

                Spacer()

                if let w = vm.weather {
                    WeatherCard(weather: w)
                        .padding(.top, 4)
                } else if vm.weatherError != nil {
                    weatherErrorBadge
                }
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: – Content sections

    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 20) {
            eventsSection
            Divider().background(Color.black.opacity(0.08))
            remindersSection
        }
    }

    // MARK: – Events

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if vm.events.isEmpty {
                sectionHeader(
                    icon: "calendar",
                    text: "Your calendar is clear today")
                Text("A peaceful day ahead — enjoy it! 😌")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                sectionHeader(
                    icon: "calendar",
                    text: "You have \(vm.events.count) event\(vm.events.count == 1 ? "" : "s") today")
                ForEach(vm.events) { event in
                    EventRow(event: event)
                }
            }
        }
    }

    // MARK: – Reminders

    private var remindersSection: some View {
        let pending = vm.reminders.filter { !$0.isCompleted }
        return VStack(alignment: .leading, spacing: 10) {
            if pending.isEmpty {
                sectionHeader(
                    icon: "checkmark.circle",
                    text: "No reminders due today")
                Text("All caught up — well done! ✅")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                sectionHeader(
                    icon: "checklist",
                    text: "And \(pending.count) reminder\(pending.count == 1 ? "" : "s") due today")
                ForEach(pending) { reminder in
                    ReminderRow(reminder: reminder)
                }
            }
        }
    }

    // MARK: – Play Button

    private var playButton: some View {
        Button {
            vm.speech.isPlaying ? vm.stopBriefing() : vm.playBriefing()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: vm.speech.isPlaying
                      ? "stop.circle.fill"
                      : "play.circle.fill")
                    .font(.system(size: 28))
                Text(vm.speech.isPlaying ? "Stop Briefing" : "Play Briefing")
                    .font(.headline)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        vm.speech.isPlaying
                            ? Color.red.opacity(0.6)
                            : Color(red: 0.6, green: 0.5, blue: 0.2).opacity(0.4),
                        lineWidth: 1.5
                    )
            )
            .foregroundStyle(
                vm.speech.isPlaying
                    ? .red
                    : Color(red: 0.45, green: 0.32, blue: 0.08)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(vm.isLoading)
        .animation(.spring(duration: 0.25), value: vm.speech.isPlaying)
    }

    // MARK: – Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(red: 0.6, green: 0.45, blue: 0.1))
            Text("Sebastian is preparing your briefing…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: – Weather error badge

    private var weatherErrorBadge: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.slash.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Location\nunavailable")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 80)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: – Helper

    private func sectionHeader(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

// MARK: - Weather Card

struct WeatherCard: View {
    let weather: WeatherData

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: weather.symbolName)
                .font(.system(size: 36))
                .symbolRenderingMode(.multicolor)

            Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(size: 28, weight: .semibold, design: .rounded))

            Text(weather.outfitEmoji)
                .font(.title2)
        }
        .padding(14)
        .frame(width: 90, height: 110)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: BriefingEvent

    private var dotColor: Color {
        Color(hex: event.calendarHex) ?? .accentColor
    }

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(dotColor)
                .frame(width: 4, height: 36)

            Text(event.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(event.timeLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Reminder Row

struct ReminderRow: View {
    let reminder: BriefingReminder

    var body: some View {
        HStack {
            Image(systemName: reminder.isCompleted
                  ? "checkmark.square.fill" : "square")
                .foregroundStyle(reminder.isCompleted ? .green : .secondary)
                .font(.title3)

            Text(reminder.title)
                .font(.subheadline)
                .lineLimit(1)
                .strikethrough(reminder.isCompleted, color: .secondary)

            Spacer()

            Text(reminder.dueDateLabel)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Playing Now Pill

struct PlayingNowPill: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            WaveformBars(animate: $animate)
            Text("Playing now")
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1))
        .foregroundStyle(.tint)
        .onAppear { animate = true }
    }
}

struct WaveformBars: View {
    @Binding var animate: Bool
    private let bars = [0.4, 0.7, 1.0, 0.6, 0.8]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(bars.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3,
                           height: animate ? bars[i] * 14 : bars[i] * 5)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.08),
                        value: animate
                    )
            }
        }
        .frame(height: 14)
    }
}

// MARK: - Color hex initializer

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double(val & 0xFF)          / 255
        )
    }
}
