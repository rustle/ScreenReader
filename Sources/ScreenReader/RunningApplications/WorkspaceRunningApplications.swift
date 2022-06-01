//
//  WorkspaceRunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AsyncAlgorithms
import Cocoa

public final class WorkspaceRunningApplications: RunningApplications {
    public var channel: AsyncChannel<Change> {
        get async {
            _channel
        }
    }
    private var _channel: AsyncChannel<Change> = .init()
    private var observer: ArrayObserver<NSWorkspace, NSRunningApplication>
    public init(workspace: NSWorkspace = .shared) async {
        let channel = self._channel
        observer = ArrayObserver(
            root: workspace,
            keypath: \.runningApplications,
            changeHandler: channel.send
        )
    }
}
