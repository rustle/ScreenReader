//
//  RunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Cocoa

public protocol RunningApplications {
    typealias Change = ArrayChange<NSRunningApplication>
    var stream: AsyncStream<Change> { get async }
}
