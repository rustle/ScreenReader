//
//  SpeechInProcess.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import AppKit
import Foundation

// NSSpeechSynthesizer drives synthesis in-process on a dedicated run-loop thread
// at .default QoS — matching the QoS of the macOS speech infrastructure to avoid
// priority inversion. startSpeaking replaces rather than queues utterances, so
// UtteranceQueue manages pending text and drives playback from the delegate.

public actor SpeechInProcess: OutputContext {
    public nonisolated let unownedExecutor: UnownedSerialExecutor
    private let speechThread: RunLoopExecutor

    @available(macOS, deprecated: 14.0)
    private var synthesizer: NSSpeechSynthesizer?
    @available(macOS, deprecated: 14.0)
    private let delegate = InProcessDelegate()

    private var queue = UtteranceQueue()

    public init() {
        let thread = RunLoopExecutor()
        thread.name = "ScreenReader.SpeechInProcess"
        thread.qualityOfService = .default
        thread.start()
        speechThread = thread
        unownedExecutor = thread.asUnownedSerialExecutor()
    }

    @available(macOS, deprecated: 14.0)
    public func submit(job: Output.Job) async throws {
        Loggers.Output.speech.debug("\(job.identifier)")
        let synth: NSSpeechSynthesizer
        if let existing = synthesizer {
            synth = existing
        } else {
            let s = NSSpeechSynthesizer()
            s.delegate = delegate
            delegate.speech = self
            synthesizer = s
            synth = s
        }
        let isInterrupt = job.options.contains(.interrupt)
        for payload in job.payloads {
            switch payload {
            case .pauseSpeech:
                synth.pauseSpeaking(at: isInterrupt ? .immediateBoundary : .wordBoundary)
            case .continueSpeech:
                synth.continueSpeaking()
            case .cancelSpeech:
                queue.cancel()
                synth.stopSpeaking(at: isInterrupt ? .immediateBoundary : .wordBoundary)
            case let .speech(text, options):
                let expanded = options?.contains(.byCharacter) == true
                    ? CharacterExpander.expand(text)
                    : text
                let interrupt = isInterrupt || options?.contains(.interrupt) == true
                Loggers.Output.speech.debug("enqueue: \(expanded)")
                switch queue.enqueue(expanded, interrupt: interrupt) {
                case .speak(let next):
                    Loggers.Output.speech.debug("startSpeaking: \(next)")
                    synth.startSpeaking(next)
                case .stopThenSpeak:
                    // didFinishSpeaking fires → utteranceDidFinish() → drains queue
                    synth.stopSpeaking(at: .immediateBoundary)
                case .wait:
                    break
                }
            case .sound:
                break
            }
        }
    }

    @available(macOS, deprecated: 14.0)
    fileprivate func utteranceDidFinish() {
        guard let synth = synthesizer, let next = queue.didFinish() else {
            return
        }
        Loggers.Output.speech.debug("startSpeaking: \(next)")
        synth.startSpeaking(next)
    }
}

@available(macOS, deprecated: 14.0)
private final class InProcessDelegate: NSObject, NSSpeechSynthesizerDelegate, @unchecked Sendable {
    // Callbacks fire on speechThread — the same executor SpeechInProcess runs on.
    weak var speech: SpeechInProcess?

    func speechSynthesizer(
        _ sender: NSSpeechSynthesizer,
        didFinishSpeaking finishedSpeaking: Bool
    ) {
        Loggers.Output.speech.debug("didFinishSpeaking: \(finishedSpeaking)")
        Task { [speech] in
            await speech?.utteranceDidFinish()
        }
    }
    func speechSynthesizer(
        _ sender: NSSpeechSynthesizer,
        didEncounterErrorAt characterIndex: Int,
        of string: String,
        message: String
    ) {
        Loggers.Output.speech.error("error at \(characterIndex): \(message)")
    }
}
