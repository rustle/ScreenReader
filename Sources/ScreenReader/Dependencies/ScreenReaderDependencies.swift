//
//  ScreenReaderDependencies.swift
//  
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Foundation

public struct ScreenReaderDependencies: Sendable {
    public let isTrusted: @Sendable (Bool) -> Bool
    public let runningApplicationsFactory: @Sendable () async throws -> RunningApplications
    public init(
        isTrusted: @escaping @Sendable (Bool) -> Bool,
        runningApplicationsFactory: @escaping @Sendable () async throws -> RunningApplications
    ) {
        self.isTrusted = isTrusted
        self.runningApplicationsFactory = runningApplicationsFactory
    }
}
