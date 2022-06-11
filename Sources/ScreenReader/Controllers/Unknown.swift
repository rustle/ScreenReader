//
//  Unknown.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Unknown<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    let element: ElementType

    private var logger: Logger {
        Loggers.Controller.unknown
    }

    private unowned let application: Application<ObserverType>

    let observer: ApplicationObserver<ObserverType>
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []

#if DEBUG
    private var cachedDebugInfo: [String:Any]?
#endif // DEBUG

    public init(
        element: ElementType,
        application: Application<ObserverType>,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.application = application
        self.observer = observer
    }
    public func start() async throws {
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
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
}

extension Unknown: ObserverHosting {}
