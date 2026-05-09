//
//  TestExecutorPool.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import RunLoopExecutor
import RunLoopExecutorPool

// Process-lifetime pool shared by tests. Actors store their executor as
// `unownedExecutor`, so a per-test `RunLoopExecutor()` is deallocated as
// soon as the helper returns and the actor's executor reference dangles —
// crashing the next job enqueue. The pool retains executors for the life
// of the test process so handing one out via `next()` is safe.
enum TestExecutorPool {
    static let shared = RunLoopExecutorFixedPool(
        name: "ScreenReaderTests",
        count: 4
    )
}
