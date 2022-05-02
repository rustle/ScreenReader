//
//  Application.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AX
import AccessibilityElement
import Cocoa
import os

public actor Application: Controller {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "Application")
    private let element: SystemElement
    public convenience init(processIdentifier: pid_t) async throws {
        try await self.init(element: try SystemElement.application(processIdentifier: processIdentifier))
    }
    public init(element: SystemElement) async throws {
        self.element = element
    }
    public func start() async throws {
        
    }
    public func stop() async throws {
        
    }
}
