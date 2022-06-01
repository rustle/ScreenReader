//
//  WorkspaceRunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AsyncAlgorithms
import AppKit
import Cocoa

public actor WorkspaceRunningApplications: RunningApplications {
    public var channel: AsyncChannel<Change> {
        _channel
    }
    private var _channel: AsyncChannel<Change>
    private let observer: ArrayObserver<NSWorkspace, NSRunningApplication>
    public init() {
        let channel = AsyncChannel<Change>()
        _channel = channel
        observer = ArrayObserver(
            root: NSWorkspace.shared,
            keypath: \.runningApplications
        ) { change in
            await channel.send(change.map({ runningApplication in
                RunningApplication(processIdentifier: runningApplication.processIdentifier,
                                   bundleIdentifier: BundleIdentifier(runningApplication.bundleIdentifier ?? "unknown"))
            }))
        }
    }
}
