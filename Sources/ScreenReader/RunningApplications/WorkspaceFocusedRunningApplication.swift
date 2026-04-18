//
//  WorkspaceFocusedRunningApplication.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import AppKit
import Cocoa

/// Delivers the pid of the frontmost application via KVO on `NSWorkspace.frontmostApplication`.
public actor WorkspaceFocusedRunningApplication: FocusedRunningApplication {
    public nonisolated let stream: AsyncStream<pid_t>
    private let observer: NSKeyValueObservation

    public init() {
        let (stream, continuation) = AsyncStream<pid_t>.makeStream()
        self.stream = stream
        observer = NSWorkspace.shared.observe(
            \.frontmostApplication,
            options: [.initial, .new]
        ) { _, change in
            guard let app = change.newValue ?? nil else { return }
            continuation.yield(app.processIdentifier)
        }
    }
}
