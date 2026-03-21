//
//  SpeechService.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import AVFoundation
import Observation

// MARK: - Service

@Observable
final class SpeechService {
    var isPlaying = false

    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SynthDelegate!

    init() {
        delegate = SynthDelegate(owner: self)
        synthesizer.delegate = delegate
    }

    /// Speak the provided text using a distinguished British English voice.
    func speak(_ text: String) {
        stop()
        configureAudioSession()
        let utterance = AVSpeechUtterance(string: text)
        // Prefer British English for the butler character
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate             = 0.46   // slightly measured
        utterance.pitchMultiplier  = 0.92   // slightly lower & richer
        utterance.preUtteranceDelay = 0.3
        synthesizer.speak(utterance)
        isPlaying = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPlaying = false
    }

    // MARK: – Script builder

    /// Builds the full butler-voiced briefing script.
    func buildScript(
        name: String,
        weather: WeatherData?,
        events: [BriefingEvent],
        reminders: [BriefingReminder]
    ) -> String {
        let greeting = timeOfDayGreeting()
        let safeName  = name.isEmpty ? "there" : name

        var lines: [String] = []

        // Opening
        lines.append("\(greeting), \(safeName). Sebastian here with your daily briefing for \(todayDateLabel()).")
        lines.append("")

        // Weather
        if let w = weather {
            lines.append("The weather outside is \(w.conditionLabel.lowercased()), with a temperature of \(Int(w.temperature.rounded())) degrees Fahrenheit.")
            lines.append(w.clothingAdvice + ".")
        } else {
            lines.append("I was unable to retrieve the weather forecast at this time.")
        }
        lines.append("")

        // Events
        if events.isEmpty {
            lines.append("Your calendar is wonderfully clear today.")
        } else {
            let n = events.count
            lines.append("You have \(n) \(n == 1 ? "event" : "events") on your calendar today.")
            for e in events {
                let time = e.isAllDay ? "all day" : "at \(e.timeLabel)"
                lines.append("\(e.title), \(time).")
            }
        }
        lines.append("")

        // Reminders
        let pending = reminders.filter { !$0.isCompleted }
        if pending.isEmpty {
            lines.append("No reminders are pending today.")
        } else {
            let n = pending.count
            lines.append("You have \(n) \(n == 1 ? "reminder" : "reminders") due today.")
            for r in pending {
                lines.append("\(r.title).")
            }
        }
        lines.append("")

        // Closing
        let period = timePeriod()
        lines.append("That concludes your briefing, \(safeName). Have a wonderful \(period). I shall be here should you need anything.")

        return lines.joined(separator: " ")
    }

    // MARK: – Private helpers

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func timeOfDayGreeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private func timePeriod() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "morning"
        case 12..<17: return "afternoon"
        default:      return "evening"
        }
    }

    private func todayDateLabel() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}

// MARK: - Private AVSpeechSynthesizerDelegate

private final class SynthDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var owner: SpeechService?
    init(owner: SpeechService) { self.owner = owner }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        owner?.isPlaying = false
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        owner?.isPlaying = false
    }
}
