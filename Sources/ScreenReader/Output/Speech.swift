//
//  Speech.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AVFoundation
import Foundation

public actor Speech: OutputContext {
    private let synthesizer: AVSpeechSynthesizer
    init() {
        synthesizer = .init()
    }
    public func submit(job: Output.Job) async throws {
        Loggers.Output.speech.debug("\(job.identifier)")
        for payload in job.payloads {
            switch payload {
            case .pauseSpeech:
                synthesizer.pauseSpeaking(at: job.options.contains(.interrupt) ? .immediate : .word)
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
}
