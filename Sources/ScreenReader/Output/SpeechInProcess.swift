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
    /// Maps the text of the in-flight NSSpeechSynthesizer utterance to its job identifier.
    /// NSSpeechSynthesizer has no utterance object, so we key on the spoken string itself.
    /// In practice only one utterance is in-flight at a time, so collisions are not a concern.
    private var currentIdentifier: String = ""
    /// Continuations waiting for a specific job identifier to finish speaking.
    private var completionContinuations: [String: CheckedContinuation<Void, Never>] = [:]

    public init() {
        let thread = RunLoopExecutor()
        thread.name = "ScreenReader.SpeechInProcess"
        thread.qualityOfService = .default
        thread.start()
        speechThread = thread
        unownedExecutor = thread.asUnownedSerialExecutor()
    }

    // MARK: - OutputContext

    @available(macOS, deprecated: 14.0)
    public func submit(job: Output.Job) async throws {
        Loggers.Output.speech.debug("\(job.identifier)")
        performSubmit(job: job)
    }

    @available(macOS, deprecated: 14.0)
    public func submitAndWait(job: Output.Job) async throws {
        guard !job.identifier.isEmpty else {
            performSubmit(job: job)
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            completionContinuations[job.identifier] = continuation
            performSubmit(job: job)
        }
    }

    // MARK: - Submit logic

    @available(macOS, deprecated: 14.0)
    private func performSubmit(job: Output.Job) {
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
                currentIdentifier = ""
                let pending = completionContinuations
                completionContinuations.removeAll()
                queue.cancel()
                synth.stopSpeaking(at: isInterrupt ? .immediateBoundary : .wordBoundary)
                for continuation in pending.values {
                    continuation.resume()
                }
            case let .speech(text, options):
                let expanded = options?.contains(.byCharacter) == true
                    ? CharacterExpander.expand(text)
                    : text
                let interrupt = isInterrupt || options?.contains(.interrupt) == true
                Loggers.Output.speech.debug("enqueue: \(expanded)")
                switch queue.enqueue(expanded, job: job, interrupt: interrupt) {
                case .speak(let entry):
                    speak(entry: entry, synthesizer: synth)
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
    private func speak(entry: UtteranceQueue.Entry,
                       synthesizer: NSSpeechSynthesizer) {
        Loggers.Output.speech.debug("startSpeaking: \(entry.text)")
        currentIdentifier = entry.job.identifier
        synthesizer.startSpeaking(entry.text)
    }

    // MARK: - Delegate callback

    @available(macOS, deprecated: 14.0)
    fileprivate func utteranceDidFinish() {
        let identifier = currentIdentifier
        currentIdentifier = ""
        if let synth = synthesizer, let next = queue.didFinish() {
            speak(entry: next, synthesizer: synth)
        }
        if !identifier.isEmpty,
           let continuation = completionContinuations.removeValue(forKey: identifier) {
            continuation.resume()
        }
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
        Task { [speech] in await speech?.utteranceDidFinish() }
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
