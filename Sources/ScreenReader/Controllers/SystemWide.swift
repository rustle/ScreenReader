//
//  SystemWide.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa
import os

public final class SystemWide: Controller {
    private let element: SystemElement
    public init() async throws {
        self.element = try SystemElement.systemWide()
    }
    public func start() async throws {}
    public func stop() async throws {}
}
