//
//  AppExecutorPool.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

// Manages a pool of RunLoopExecutors for observed applications.
// Executors are acquired for the duration of withRunLoopExecutor and
// released automatically when the body returns or throws.
//
// The pool grows on demand up to `maximumWidth`. Once at maximumWidth,
// withRunLoopExecutor provides the least-loaded active executor rather than
// spawning a new thread. Released executors with no remaining users move to
// the idle list for immediate reuse.
public final class AppExecutorPool: Sendable {
    private struct State {
        var idle: [RunLoopExecutor] = []
        var active: [(executor: RunLoopExecutor, count: Int)] = []
        let maximumWidth: Int
    }
    private let state: OSAllocatedUnfairLock<State>

    public init(maximumWidth: Int = ProcessInfo.processInfo.activeProcessorCount) {
        state = .init(uncheckedState: State(maximumWidth: maximumWidth))
    }

    public func withRunLoopExecutor<T: Sendable>(
        _ body: @Sendable (RunLoopExecutor) async throws -> T
    ) async rethrows -> T {
        let executor = acquire()
        defer { release(executor) }
        return try await body(executor)
    }

    private func acquire() -> RunLoopExecutor {
        state.withLock { state in
            // Prefer an idle (previously used, now free) executor
            if let executor = state.idle.popLast() {
                state.active.append((executor, 1))
                return executor
            }
            // Under cap: spin up a new thread
            if state.active.count < state.maximumWidth {
                let executor = RunLoopExecutor()
                executor.start()
                state.active.append((executor, 1))
                return executor
            }
            // At cap: share the least-loaded active executor
            let index = state.active.indices.min { state.active[$0].count < state.active[$1].count }!
            state.active[index].count += 1
            return state.active[index].executor
        }
    }

    private func release(_ executor: RunLoopExecutor) {
        state.withLock { state in
            guard let index = state.active.firstIndex(where: { $0.executor === executor }) else { return }
            state.active[index].count -= 1
            if state.active[index].count == 0 {
                let freed = state.active.remove(at: index).executor
                state.idle.append(freed)
            }
        }
    }
}
