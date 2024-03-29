//
//  WorkspaceRunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AppKit
import Cocoa

public actor WorkspaceRunningApplications: RunningApplications {
    public var stream: AsyncStream<Change> {
        _stream
    }
    private let _stream: AsyncStream<ArrayChange<RunningApplication>>
    private let observer: ArrayObserver<NSWorkspace, NSRunningApplication>
    public init() {
        let (stream, continuation) = AsyncStream<ArrayChange<RunningApplication>>.makeStream()
        _stream = stream
        observer = ArrayObserver(
            root: NSWorkspace.shared,
            keypath: \.runningApplications
        ) { change in
            continuation.yield(change.map({ runningApplication in
                RunningApplication(processIdentifier: runningApplication.processIdentifier,
                                   bundleIdentifier: BundleIdentifier(runningApplication.bundleIdentifier ?? "unknown"))
            }))
        }
    }
}
