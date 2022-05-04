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
    private let element: ElementType
    private let observer: ApplicationObserver<ObserverType>
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []
    public init(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        Loggers.list.info("\(#function) \(self.element)")
        observerTokens.append(try await observer.add(
            element: element,
            notification: .selectedChildrenChanged,
            handler: isolated(action: List<ObserverType>.selectedChildrenChanged)
        ))
    }
    public func stop() async throws {
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {
            Loggers.list.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
    private func selectedChildrenChanged(
        element: ElementType,
        userInfo: [String:Any]
    ) async {
        Loggers.list.info("\(#function) \(element)")
    }
}
