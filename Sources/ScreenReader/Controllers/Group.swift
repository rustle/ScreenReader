//
//  Group.swift
//  
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Group<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
    public var identifier: AnyHashable {
        element
    }

    public nonisolated let unownedExecutor: UnownedSerialExecutor
    let observer: ApplicationObserver<ObserverType>

    private var observerTasks: [Task<Void, any Error>] = []
    private var runState: RunState = .stopped
    private let output: AsyncStream<Output.Job>.Continuation
    private var logger: Logger {
        Loggers.Controller.group
    }

    public init(
        element: ElementType,
        output: AsyncStream<Output.Job>.Continuation,
        observer: ApplicationObserver<ObserverType>,
        executor: RunLoopExecutor
    ) async throws {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
        self.element = element
        self.output = output
        self.observer = observer
    }
    public func start() async throws {
        logger.debug("\(self.element)")
        guard runState == .stopped else { return }
        runState = .running
    }
    public func stop() async throws {
        logger.debug("\(self.element)")
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    public func focus() async throws {
        logger.debug("\(self.element)")
    }
}

extension Group: ObserverHosting {}
