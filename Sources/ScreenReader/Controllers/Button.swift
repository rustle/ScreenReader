//
//  Button.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os
import TargetAction

public final class Button<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType

    private var logger: Logger {
        Loggers.Controller.button
    }

    let observer: ApplicationObserver<ObserverType>
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []

    public init(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        logger.info("\(#function) \(self.element)")
        do {
            observerTokens.append(try await add(
                notification: .valueChanged,
                handler: TargetAction.target(
                    self,
                    action: Button<ObserverType>.valueChanged
                )
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
    }
    public func focus() async throws {
        logger.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        do {
            try await remove(tokens: observerTokens)
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.info("\(#function) \(element)")
    }
}

extension Button: ObserverHosting {}
