//
//  List.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import TargetAction
import os

public final class List<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType

    private var logger: Logger {
        Loggers.Controller.list
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
                notification: .selectedChildrenChanged,
                handler: TargetAction.target(
                    self,
                    action: List<ObserverType>.selectedChildrenChanged
                )
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        await selectedChildrenChanged(
            element: element,
            userInfo: nil
        )
    }
    public func stop() async throws {
        do {
            try await remove(tokens: observerTokens)
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
    private func selectedChildrenChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.info("\(#function) \(element)")
        do {
            let children = try element.selectedChildren()
            logger.info("\(#function) \(children)")
        } catch {
            logger.error("\(#function) \(error.localizedDescription)")
        }
    }
}

extension List: ObserverHosting {}
