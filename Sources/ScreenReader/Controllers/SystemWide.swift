//
//  SystemWide.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa
import os

public actor SystemWide: Controller {
    private let element: SystemElement
    public var identifier: AnyHashable {
        element
    }
    public init() async throws {
        self.element = try SystemElement.systemWide()
    }
    public func start() async throws {}
    public func stop() async throws {}
}
