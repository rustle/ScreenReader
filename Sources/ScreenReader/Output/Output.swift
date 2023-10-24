//
//  Output.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import Foundation

public protocol OutputContext {
    func submit(job: Output.Job) async throws
}

public actor Output: OutputContext {
    public struct Options: OptionSet {
        public let rawValue: Int
        public static let interrupt = Options(rawValue: 1 << 0)
        public static let punctuation = Options(rawValue: 1 << 1)
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    public struct Job {
        public let options: Options
        public let identifier: String
        public enum Payload {
            case pauseSpeech
            case continueSpeech
            case cancelSpeech
            case speech(String, Options?)
            case sound([String], [Int], [TimeInterval])
        }
        public let payloads: [Payload]
        public init(
            options: Options,
            identifier: String,
            payloads: [Payload]
        ) {
            self.options = options
            self.identifier = identifier
            self.payloads = payloads
        }
    }
    private let contexts: [OutputContext] = [
        Speech(),
        Text(),
        Braille(),
    ]
    public func submit(job: Job) async throws {
        Loggers.Output.output.debug("\(job)")
        for context in contexts {
            try await context.submit(job: job)
        }
    }
}

extension Output.Job: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        debugDescription
    }
    public var debugDescription: String {
        "Identifier: \(identifier), Options: \(options), Payloads: \(payloads)"
    }
}

extension Output.Job.Payload: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        debugDescription
    }
    public var debugDescription: String {
        switch self {
        case .pauseSpeech:
            return "Pause"
        case .continueSpeech:
            return "Continue"
        case .cancelSpeech:
            return "Cancel"
        case .speech(let text, let options):
            return "Speech: \(text), Options: \(String(describing: options))"
        case .sound(let name, let count, let cadence):
            return "Sound: \(name), Count: \(count), Cadence: \(cadence)"
        }
    }
}
