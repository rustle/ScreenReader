//
//  Server.swift
//
//  Copyright © 2017-2021 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Server {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "Server")
    public let processIdentifier: pid_t
    public let bundleIdentifier: BundleIdentifier
    private let element: Element
    public init(processIdentifier: pid_t,
                bundleIdentifier: BundleIdentifier) async throws {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.element = try SystemElement.application(processIdentifier: processIdentifier)
    }
}
