//
//  WorkspaceRunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Cocoa

public actor WorkspaceRunningApplications: RunningApplications {
    public var stream: AsyncStream<Change> {
        get async {
            _stream
        }
    }
    private let _stream: AsyncStream<ArrayChange<NSRunningApplication>>
    private let observer: ArrayObserver<NSWorkspace, NSRunningApplication>
    public init(workspace: NSWorkspace = .shared) async {
        // TODO: This can probably become an AsyncChannel to allow for backpressure
        // TODO: This shouldn't have to depend on AsyncStream calling it's build closure right away to provide the continuation
        var continuation: AsyncStream<ArrayChange<NSRunningApplication>>.Continuation!
        _stream = AsyncStream<ArrayChange<NSRunningApplication>> { continuation = $0 }
        assert(continuation != nil)
        observer = ArrayObserver(
            root: workspace,
            keypath: \.runningApplications
        ) { change in
            continuation.yield(change)
        }
    }
}
