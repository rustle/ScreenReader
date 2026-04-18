//
//  ScreenReaderDependencies.swift
//  
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Foundation

public struct ScreenReaderDependencies: Sendable {
    public let isTrusted: @Sendable (Bool) -> Bool
    public let runningApplicationsFactory: @Sendable () async throws -> any RunningApplications
    public let focusedRunningApplicationFactory: @Sendable () async throws -> any FocusedRunningApplication
    public let outputContextsFactory: @Sendable () -> [any OutputContext]
    public init(
        isTrusted: @escaping @Sendable (Bool) -> Bool,
        runningApplicationsFactory: @escaping @Sendable () async throws -> any RunningApplications,
        focusedRunningApplicationFactory: @escaping @Sendable () async throws -> any FocusedRunningApplication,
        outputContextsFactory: @escaping @Sendable () -> [any OutputContext]
    ) {
        self.isTrusted = isTrusted
        self.runningApplicationsFactory = runningApplicationsFactory
        self.focusedRunningApplicationFactory = focusedRunningApplicationFactory
        self.outputContextsFactory = outputContextsFactory
    }
}
