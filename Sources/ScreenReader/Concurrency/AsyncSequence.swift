//
//  AsyncSequence.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

extension AsyncSequence {
    func target<T: AnyObject>(
        _ target: T,
        detached: Bool = false,
        priority: TaskPriority? = nil,
        action: @escaping @Sendable (T) -> (Element) async -> Void
    ) -> Task<Void, any Error> where T: Sendable {
        let operation: @Sendable () async throws -> Void = { [weak target] in
            for try await value in self {
                try Task.checkCancellation()
                guard let target = target else {
                    return
                }
                await action(target)(value)
            }
        }
        if detached {
            return Task.detached(
                priority: priority,
                operation: operation
            )
        } else {
            return Task(
                priority: priority,
                operation: operation
            )
        }
    }
    func target<T: Actor>(
        _ target: T,
        detached: Bool = false,
        priority: TaskPriority? = nil,
        action: @escaping (isolated T) -> (Element) async -> Void
    ) -> Task<Void, any Error> {
        let operation: @Sendable () async throws -> Void = { [weak target] in
            for try await value in self {
                try Task.checkCancellation()
                guard let target = target else {
                    return
                }
                await action(target)(value)
            }
        }
        if detached {
            return Task.detached(
                priority: priority,
                operation: operation
            )
        } else {
            return Task(
                priority: priority,
                operation: operation
            )
        }
    }
    func sink(
        detached: Bool = false,
        priority: TaskPriority? = nil,
        receiveValue: @escaping @Sendable (Element) async -> Void
    ) -> Task<Void, any Error> {
        let operation: @Sendable () async throws -> Void = {
            for try await value in self {
                try Task.checkCancellation()
                await receiveValue(value)
            }
        }
        if detached {
            return Task.detached(
                priority: priority,
                operation: operation
            )
        } else {
            return Task(
                priority: priority,
                operation: operation
            )
        }
    }
}
