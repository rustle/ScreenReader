//
//  Braille.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import Foundation

public actor Braille: OutputContext {
    public func submit(job: Output.Job) async throws {
        Loggers.Output.braille.debug("\(job)")
    }
}
