//
//  RunningApplications.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AppKit
import Cocoa

public struct RunningApplication: Hashable, Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: BundleIdentifier
}

public protocol RunningApplications: Sendable {
    typealias Change = ArrayChange<RunningApplication>
    var stream: AsyncStream<Change> { get async }
}
