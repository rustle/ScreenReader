//
//  List.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor List<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
    private unowned let application: Application<ObserverType>
    let observer: ApplicationObserver<ObserverType>
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []
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
        Loggers.Controller.list.info("\(#function) \(self.element)")
        do {
            observerTokens.append(try await add(
                notification: .selectedChildrenChanged,
                handler: target(action: List<ObserverType>.selectedChildrenChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.list.info("\(error.localizedDescription)")
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
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {
            Loggers.Controller.list.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
    private func selectedChildrenChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.Controller.list.info("\(#function) \(element)")
        do {
            let children = try element.selectedChildren()
            Loggers.Controller.list.info("\(#function) \(children)")
        } catch {
            Loggers.Controller.list.error("\(#function) \(error.localizedDescription)")
        }
    }
}

extension List: ObserverHosting {}
