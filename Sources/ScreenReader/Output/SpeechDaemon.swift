//
//  SpeechDaemon.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import AVFoundation
import Foundation

// AVSpeechSynthesizer communicates with the system speech daemon via XPC.
// We manage our UtteranceQueue so that only one utterance is in-flight
// at a time (AVSpeechSynthesizer's built-in queue is bypassed).

public actor SpeechDaemon: OutputContext {
    private var synthesizer: AVSpeechSynthesizer?
    private let delegate = DaemonDelegate()

    private var queue = UtteranceQueue()
    
    public init() {}

    public func submit(job: Output.Job) async throws {
        Loggers.Output.speech.debug("\(job.identifier)")
        let synth: AVSpeechSynthesizer
        if let existing = synthesizer {
            synth = existing
        } else {
            let s = AVSpeechSynthesizer()
            s.delegate = delegate
            delegate.speech = self
            synthesizer = s
            synth = s
        }
        let isInterrupt = job.options.contains(.interrupt)
        for payload in job.payloads {
            switch payload {
            case .pauseSpeech:
                synth.pauseSpeaking(at: isInterrupt ? .immediate : .word)
            case .continueSpeech:
                synth.continueSpeaking()
            case .cancelSpeech:
                queue.cancel()
                synth.stopSpeaking(at: isInterrupt ? .immediate : .word)
            case let .speech(text, options):
                let expanded = options?.contains(.byCharacter) == true
                    ? CharacterExpander.expand(text)
                    : text
                let interrupt = isInterrupt || options?.contains(.interrupt) == true
                Loggers.Output.speech.debug("enqueue: \(expanded)")
                switch queue.enqueue(expanded, interrupt: interrupt) {
                case .speak(let next):
                    Loggers.Output.speech.debug("speak: \(next)")
                    synth.speak(AVSpeechUtterance(string: next))
                case .stopThenSpeak:
                    // didCancel fires → utteranceDidFinish() → drains queue
                    synth.stopSpeaking(at: .immediate)
                case .wait:
                    break
                }
            case .sound:
                break
            }
        }
    }

    fileprivate func utteranceDidFinish() {
        guard let synth = synthesizer, let next = queue.didFinish() else { return }
        Loggers.Output.speech.debug("speak: \(next)")
        synth.speak(AVSpeechUtterance(string: next))
    }
}

private final class DaemonDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    // Weak to avoid a retain cycle; SpeechDaemon holds the delegate strongly.
    weak var speech: SpeechDaemon?

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Loggers.Output.speech.debug("didFinish")
        Task { [speech] in await speech?.utteranceDidFinish() }
    }
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Loggers.Output.speech.debug("didCancel")
        Task { [speech] in
            await speech?.utteranceDidFinish()
        }
    }
}
