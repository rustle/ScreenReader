//
//  Output.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Foundation

public protocol OutputContext: Sendable {
    func submit(job: Output.Job) async throws
    /// Submit a job and suspend until its speech payloads have finished playing
    /// (or been cancelled). Jobs with an empty identifier fall through to `submit`.
    func submitAndWait(job: Output.Job) async throws
}

extension OutputContext {
    public func submitAndWait(job: Output.Job) async throws {
        try await submit(job: job)
    }
}

public actor Output: OutputContext {
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int
        public static let interrupt = Options(rawValue: 1 << 0)
        public static let byCharacter = Options(rawValue: 1 << 1)
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    public struct Job: Sendable {
        public let options: Options
        public let identifier: String
        public enum Payload: Sendable {
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
    private let contexts: [any OutputContext]

    public init(contexts: [any OutputContext]) {
        self.contexts = contexts
    }

    public func submit(job: Job) async throws {
        Loggers.Output.output.debug("\(job)")
        for context in contexts {
            try await context.submit(job: job)
        }
    }

    public func submitAndWait(job: Job) async throws {
        Loggers.Output.output.debug("submitAndWait \(job)")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for context in contexts {
                group.addTask { try await context.submitAndWait(job: job) }
            }
            try await group.waitForAll()
        }
    }

    public func cancel() async throws {
        try await submit(job: .init(
            options: [.interrupt],
            identifier: "cancel",
            payloads: [.cancelSpeech]
        ))
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
