//
//  Text.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Cocoa

public actor Text: OutputContext {
    private var overlay: Overlay?

    public init() {}

    public func submit(job: Output.Job) async throws {
        let strings = job.payloads.compactMap { payload -> String? in
            guard case .speech(let text, _) = payload else { return nil }
            return text
        }
        guard !strings.isEmpty else { return }
        let overlay = await currentOverlay()
        await overlay.show(strings.joined(separator: " "))
    }

    private func currentOverlay() async -> Overlay {
        if let existing = overlay { return existing }
        let new = await MainActor.run { Overlay() }
        overlay = new
        return new
    }
}
