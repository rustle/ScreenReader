//
//  ScreenReaderDependencies.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Foundation
import os

public struct ScreenReaderDependencies {
    public let logger = Logger(
        subsystem: "ScreenReader",
        category: "ScreenReader"
    )
    public let isTrusted: (Bool) -> Bool
    public let runningApplicationsFactory: () async throws -> RunningApplications
    public init(
        isTrusted: @escaping (Bool) -> Bool,
        runningApplicationsFactory: @escaping () async throws -> RunningApplications
    ) {
        self.isTrusted = isTrusted
        self.runningApplicationsFactory = runningApplicationsFactory
    }
}
