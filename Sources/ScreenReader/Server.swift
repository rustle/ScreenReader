//
//  Server.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public enum ServerError: Error {
    case application(ApplicationError)
}

public actor Server {
    public let processIdentifier: pid_t
    public let bundleIdentifier: BundleIdentifier
    private let application: Controller

    public init(
        processIdentifier: pid_t,
        bundleIdentifier: BundleIdentifier,
        application: Controller
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.application = application
    }

    public func start() async throws {
        do {
            try await application.start()
        } catch let error as ApplicationError {
            throw ServerError.application(error)
        } catch {
            throw error
        }
    }

    public func stop() async throws {
        do {
            try await application.stop()
        } catch let error as ApplicationError {
            throw ServerError.application(error)
        } catch {
            throw error
        }
    }

    public func yield() async throws {
        try await Yield().yield()
    }
}

private final class Yield: Sendable {
    private let state = OSAllocatedUnfairLock<CheckedContinuation<Void, Error>?>(uncheckedState: nil)
    func yield() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                state.withLock {
                    $0 = continuation
                }
            }
        } onCancel: {
            cancelYieldIfNeeded()
        }
    }

    private func cancelYieldIfNeeded() {
        let continuation = state.withLock {
            let continuation = $0
            $0 = nil
            return continuation
        }
        continuation?.resume(throwing: CancellationError())
    }
}
