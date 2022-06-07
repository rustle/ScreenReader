//
//  Unknown.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public final class Unknown<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    let element: ElementType

    private var logger: Logger {
        Loggers.Controller.unknown
    }

    let observer: ApplicationObserver<ObserverType>
    private var observerTasks: [Task<Void, any Error>] = []

    private var runState: RunState = .stopped

#if DEBUG
    private var cachedDebugInfo: [String:Any]?
#endif // DEBUG

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
#if DEBUG
        if let element = element as? SystemElement {
            cachedDebugInfo = element.debugInfo
        } else {
            cachedDebugInfo = ["Description": element.description]
        }
#endif // DEBUG
    }
    public func focus() async throws {
        logger.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
#if DEBUG
        if let cachedDebugInfo = cachedDebugInfo {
            logger.info("\(#function) \(self.element) \(cachedDebugInfo)")
        } else {
            logger.info("\(#function) \(self.element)")
        }
#else
        logger.info("\(#function) \(self.element)")
#endif // DEBUG
        observerTasks.cancel()
    }
}

extension Unknown: ObserverHosting {}
