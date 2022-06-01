//
//  RunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AsyncAlgorithms
import AppKit
import Cocoa

public struct RunningApplication: Hashable, Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: BundleIdentifier
}

public protocol RunningApplications: Sendable {
    typealias Change = ArrayChange<RunningApplication>
    var channel: AsyncChannel<Change> { get async }
}
