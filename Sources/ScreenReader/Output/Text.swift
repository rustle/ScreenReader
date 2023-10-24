//
//  Text.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import Foundation

public actor Text: OutputContext {
    public func submit(job: Output.Job) async throws {
        Loggers.Output.text.debug("\(job)")
    }
}
