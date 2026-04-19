//
//  SpeechQueue.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

// Shared utterance queue for SpeechInProcess and SpeechDaemon.
// Intentionally not Sendable — must only be mutated from within
// the owning actor.
struct UtteranceQueue {
    /// A pending or in-flight speech item. Carries the job so the identifier
    /// is available when the synthesizer delegate fires.
    struct Entry: Sendable {
        /// Expanded text ready for the synthesizer.
        let text: String
        /// The job that produced this utterance, preserved for identifier lookup.
        let job: Output.Job
    }

    private var pending: [Entry] = []
    private(set) var isSpeaking = false

    enum EnqueueResult {
        /// Begin speaking this entry immediately.
        case speak(Entry)
        /// Stop the current utterance; the delegate's didFinish callback will drain the queue.
        case stopThenSpeak
        /// Already speaking; the delegate's didFinish callback will drain the queue.
        case wait
    }

    /// Add `text` to the queue. If `interrupt` is true the pending queue is
    /// cleared first so only this utterance remains.
    mutating func enqueue(
        _ text: String,
        job: Output.Job,
        interrupt: Bool
    ) -> EnqueueResult {
        if interrupt {
            pending.removeAll()
        }
        pending.append(Entry(text: text, job: job))
        if interrupt && isSpeaking {
            return .stopThenSpeak
        } else if !isSpeaking {
            isSpeaking = true
            return .speak(pending.removeFirst())
        } else {
            return .wait
        }
    }

    /// Clear all pending utterances and mark the synthesizer as idle.
    /// The caller is responsible for stopping the underlying synthesizer.
    mutating func cancel() {
        pending.removeAll()
        isSpeaking = false
    }

    /// Call from the synthesizer's didFinish/didCancel delegate callback.
    /// Returns the next entry to speak, or nil if the queue is empty.
    mutating func didFinish() -> Entry? {
        isSpeaking = false
        guard !pending.isEmpty else {
            return nil
        }
        isSpeaking = true
        return pending.removeFirst()
    }
}
