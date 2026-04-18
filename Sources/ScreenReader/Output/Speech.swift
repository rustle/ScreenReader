//
//  Speech.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import AVFoundation
import Foundation

public actor Speech: OutputContext {
    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        weak var speech: Speech?

        func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            didFinish utterance: AVSpeechUtterance
        ) {
            Loggers.Output.speech.debug("didFinish")
            Task { [speech] in await
                speech?.utteranceDidFinish()
            }
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
    
    private var synthesizer: AVSpeechSynthesizer?
    private let delegate = Delegate()

    public func submit(job: Output.Job) async throws {
        Loggers.Output.speech.debug("\(job.identifier)")
        let synthesizer: AVSpeechSynthesizer
        if let existing = self.synthesizer {
            synthesizer = existing
        } else {
            synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = delegate
            delegate.speech = self
        }
        let isInterrupt = job.options.contains(.interrupt)
        for payload in job.payloads {
            switch payload {
            case .pauseSpeech:
                synthesizer.pauseSpeaking(at: isInterrupt ? .immediate : .word)
            case .continueSpeech:
                synthesizer.continueSpeaking()
            case .cancelSpeech:
                synthesizer.stopSpeaking(at: job.options.contains(.interrupt) ? .immediate : .word)
            case let .speech(speech, _):
                Loggers.Output.speech.debug("\(speech)")
                synthesizer.speak(AVSpeechUtterance(string: speech))
            case .sound(_, _, _):
                break
            }
        }
    }

    fileprivate func utteranceDidFinish() {
    }
}
