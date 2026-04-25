//
//  ServerProvider.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Foundation
import os
import RunLoopExecutorPool

public enum ServerProviderError: Error {
    case ignored
}

public actor ServerProvider {
    private let exclusionList: Set<BundleIdentifier>
    private let inclusionList: Set<BundleIdentifier>
    private let logger: Logger
    private let pool = RunLoopExecutorDynamicPool(
        name: "ScreenReader.Application",
        qualityOfService: .userInitiated
    )

    public init(dependencies: ServerProviderDependencies) {
        logger = dependencies.logger
        exclusionList = dependencies.exclusionListFactory()
        inclusionList = dependencies.inclusionListFactory()
    }

    /// Acquires a RunLoopExecutor, creates and starts a Server, calls `body`,
    /// then stops the Server and releases the executor — even if `body` throws
    /// or the task is cancelled.
    public func withServer(
        processIdentifier: pid_t,
        bundleIdentifier: BundleIdentifier,
        output: Output,
        @_inheritActorContext _ body: @Sendable (Server, isolated (any Actor)?) async throws -> Void,
        _ isolation: (any Actor)? = #isolation
    ) async throws {
        guard processIdentifier != getpid() else {
            throw ServerProviderError.ignored
        }
        if !exclusionList.isEmpty, exclusionList.contains(bundleIdentifier) {
            throw ServerProviderError.ignored
        }
        if !inclusionList.isEmpty, !inclusionList.contains(bundleIdentifier) {
            throw ServerProviderError.ignored
        }
        logger.debug("Connect \(bundleIdentifier) -- \(processIdentifier)")
        try await pool.withRunLoopExecutor { executor in
            let application = try await Application(
                processIdentifier: processIdentifier,
                output: output,
                executor: executor
            )
            let server = Server(
                processIdentifier: processIdentifier,
                bundleIdentifier: bundleIdentifier,
                application: application
            )
            try await server.start()
            do {
                try await body(server, isolation)
            } catch {
                try? await server.stop()
                throw error
            }
            try await server.stop()
        }
    }
}
