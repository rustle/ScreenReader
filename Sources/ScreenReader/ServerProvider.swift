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
    // TODO: Source this from a plist or a DB
    private let ignoreList = Set<BundleIdentifier>([
        "com.apple.webkit.databases",
        "com.apple.webkit.networking",
    ])
    public func connect(processIdentifier: pid_t,
                        bundleIdentifier: BundleIdentifier,
                        updateFocusOnConnect: Bool = false) async throws -> Server {
        Self.logger.info("Connect \(bundleIdentifier) -- \(processIdentifier) -- updateFocusOnConnect \(updateFocusOnConnect)")
        guard !ignoreList.contains(bundleIdentifier) && processIdentifier != getpid() else {
            throw ServerProviderError.ignored
        }
        return try await .init(processIdentifier: processIdentifier,
                               bundleIdentifier: bundleIdentifier)
    }
}
