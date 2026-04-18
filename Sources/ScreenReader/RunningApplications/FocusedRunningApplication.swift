//
//  FocusedRunningApplication.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Darwin

/// A source that delivers the pid of the frontmost application each time it changes.
public protocol FocusedRunningApplication: Sendable {
    var stream: AsyncStream<pid_t> { get }
}
