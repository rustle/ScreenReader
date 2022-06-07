//
//  Window.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public final class Window<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType

    let observer: ApplicationObserver<ObserverType>
    private var observerTasks: [Task<Void, any Error>] = []

    private var logger: Logger {
        Loggers.Controller.window
    }

    private var runState: RunState = .stopped

    public init(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        guard runState == .stopped else { return }
        logger.info("\(#function) \(self.element)")
        runState = .started
    }
    public func stop() async throws {
        guard runState == .started else { return }
        logger.info("\(#function) \(self.element)")
        observerTasks.cancel()
        runState = .stopped
    }
}

extension Window: ObserverHosting {}
