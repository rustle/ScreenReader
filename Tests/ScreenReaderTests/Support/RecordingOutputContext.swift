//
//  RecordingOutputContext.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import ScreenReader

// OutputContext that records submitted jobs as an AsyncStream and tracks the
// total submission count. Tests use jobs.prefix(N) to wait for N submissions,
// or check submitCount after Task.yield() to verify nothing was submitted.
actor RecordingOutputContext: OutputContext {
    nonisolated let jobs: AsyncStream<Output.Job>
    private let continuation: AsyncStream<Output.Job>.Continuation
    private(set) var submitCount: Int = 0

    init() {
        (jobs, continuation) = AsyncStream.makeStream()
    }

    func submit(job: Output.Job) async throws {
        submitCount += 1
        continuation.yield(job)
    }

    func submitAndWait(job: Output.Job) async throws {
        submitCount += 1
        continuation.yield(job)
    }
}
