//
//  ServerProvider.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Foundation
import os

public enum ServerProviderError: Error {
    case ignored
}

public actor ServerProvider {
    private let exclusionList: Set<BundleIdentifier>
    private let inclusionList: Set<BundleIdentifier>
    private let logger: Logger
    public init(dependencies: ServerProviderDependencies) {
        logger = dependencies.logger
        exclusionList = dependencies.exclusionListFactory()
        inclusionList = dependencies.inclusionListFactory()
    }
    public func connect(
        processIdentifier: pid_t,
        bundleIdentifier: BundleIdentifier,
        output: Output,
        updateFocusOnConnect: Bool = false
    ) async throws -> Server {
        logger.info("Connect \(bundleIdentifier) -- \(processIdentifier) -- updateFocusOnConnect \(updateFocusOnConnect)")
        guard processIdentifier != getpid() else {
            throw ServerProviderError.ignored
        }
        if !exclusionList.isEmpty, exclusionList.contains(bundleIdentifier) {
            throw ServerProviderError.ignored
        }
        if !inclusionList.isEmpty, !inclusionList.contains(bundleIdentifier) {
            throw ServerProviderError.ignored
        }
        return try await .init(
            processIdentifier: processIdentifier,
            bundleIdentifier: bundleIdentifier,
            output: output
        )
    }
}
