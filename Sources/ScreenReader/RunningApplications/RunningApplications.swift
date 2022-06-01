//
//  RunningApplications.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AsyncAlgorithms
import Cocoa

public protocol RunningApplications {
    typealias Change = ArrayChange<NSRunningApplication>
    var channel: AsyncChannel<Change> { get async }
}
