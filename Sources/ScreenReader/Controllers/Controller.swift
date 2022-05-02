//
//  Controller.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

public protocol Controller {
    func start() async throws
    func stop() async throws
}
