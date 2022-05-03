//
//  Text.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Foundation

public actor Text: OutputContext {
    public func submit(job: Output.Job) async throws {
        Loggers.Output.text.info("\(#function) \(job)")
    }
}
