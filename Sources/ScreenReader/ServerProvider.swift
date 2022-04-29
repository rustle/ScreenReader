//
//  ServerProvider.swift
//
//  Copyright © 2017-2021 Doug Russell. All rights reserved.
//

import Foundation
import os

public enum ServerProviderError: Error {
    case ignored
}

public actor ServerProvider {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "ServerProvider")
    private let ignoreList = Set<BundleIdentifier>([])
    public func connect(processIdentifier: pid_t,
                        bundleIdentifier: BundleIdentifier,
                        updateFocusOnConnect: Bool = false) async throws -> Server {
        Self.logger.info("Connect \(bundleIdentifier) -- \(processIdentifier) -- updateFocusOnConnect \(updateFocusOnConnect)")
        guard !ignoreList.contains(bundleIdentifier) else {
            throw ServerProviderError.ignored
        }
        return try await .init(processIdentifier: processIdentifier,
                               bundleIdentifier: bundleIdentifier)
    }
}
