//
//  RunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Cocoa

public protocol RunningApplications {
    func stream() async -> AsyncStream<ArrayChange<NSRunningApplication>>
}
