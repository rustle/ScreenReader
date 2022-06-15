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
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []

    private var logger: Logger {
        Loggers.Controller.window
    }

    public init(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        logger.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        logger.info("\(#function) \(self.element)")
        do {
            try await remove(tokens: observerTokens)
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
}

extension Window: ObserverHosting {}
