//
//  Controller.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement

public protocol Controller {
    func start() async throws
    func stop() async throws
    func focus() async throws
}

extension Controller {
    public func focus() async throws {}
}
