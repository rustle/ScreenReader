//
//  Braille.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Foundation
import Braille

public actor Braille: OutputContext {
    private let display: any BrailleDisplay

    public init(display: any BrailleDisplay) {
        self.display = display
    }
    public init() {
        display = BrlAPIDisplay()
    }

    public func connect() async throws {
        try await display.connect()
    }

    public func disconnect() async throws {
        try await display.disconnect()
    }

    public func submit(job: Output.Job) async throws {
        let strings = job.payloads.compactMap { payload -> String? in
            guard case .speech(let text, _) = payload else { return nil }
            return text
        }
        guard !strings.isEmpty else { return }
        try await display.write(text: strings.joined(separator: " "))
    }
}
