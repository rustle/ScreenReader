//
//  Server.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Server {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "Server")
    public let processIdentifier: pid_t
    public let bundleIdentifier: BundleIdentifier
    private let application: Application
    public init(
        processIdentifier: pid_t,
        bundleIdentifier: BundleIdentifier
    ) async throws {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        application = try await Application(processIdentifier: processIdentifier)
    }
    public func start() async throws {
        try await application.start()
    }
    public func stop() async throws {
        try await application.stop()
    }
}
