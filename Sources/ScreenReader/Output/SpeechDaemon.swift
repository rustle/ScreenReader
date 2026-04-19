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
    /// Maps an in-flight AVSpeechUtterance to its job identifier (non-empty jobs only).
    private var utteranceIdentifiers: [ObjectIdentifier: String] = [:]
    /// Continuations waiting for a specific job identifier to finish speaking.
    private var completionContinuations: [String: CheckedContinuation<Void, Never>] = [:]

    public init() {}

    // MARK: - OutputContext

    public func submit(job: Output.Job) async throws {
        Loggers.Output.speech.debug("\(job.identifier)")
        performSubmit(job: job)
    }

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

    // MARK: - Core submit logic (synchronous, actor-isolated)

    /// Synchronous body of submit — safe to call from within withCheckedContinuation.
    private func performSubmit(job: Output.Job) {
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
                // Clear identifier mappings before stopping so utteranceDidFinish
                // cannot double-resume continuations via the didCancel path.
                utteranceIdentifiers.removeAll()
                let pending = completionContinuations
                completionContinuations.removeAll()
                queue.cancel()
                synth.stopSpeaking(at: isInterrupt ? .immediate : .word)
                // Unblock any submitAndWait callers immediately.
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
                    speak(entry: entry, synth: synth)
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

    private func speak(entry: UtteranceQueue.Entry, synth: AVSpeechSynthesizer) {
        Loggers.Output.speech.debug("speak: \(entry.text)")
        let utterance = AVSpeechUtterance(string: entry.text)
        if !entry.job.identifier.isEmpty {
            utteranceIdentifiers[ObjectIdentifier(utterance)] = entry.job.identifier
        }
        synth.speak(utterance)
    }

    // MARK: - Delegate callback

    fileprivate func utteranceDidFinish(_ utteranceID: ObjectIdentifier) {
        let identifier = utteranceIdentifiers.removeValue(forKey: utteranceID)
        // Drain queue before resuming continuation so the next utterance is
        // already enqueued by the time the submitAndWait caller wakes.
        if let synth = synthesizer, let next = queue.didFinish() {
            speak(entry: next, synth: synth)
        }
        if let id = identifier,
           let continuation = completionContinuations.removeValue(forKey: id) {
            continuation.resume()
        }
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
        let id = ObjectIdentifier(utterance)
        Task { [speech] in await speech?.utteranceDidFinish(id) }
    }
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Loggers.Output.speech.debug("didCancel")
        let id = ObjectIdentifier(utterance)
        Task { [speech] in await speech?.utteranceDidFinish(id) }
    }
}
