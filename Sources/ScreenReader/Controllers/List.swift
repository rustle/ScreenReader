//
//  List.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor List: Controller {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "List")
    private let element: SystemElement
    private let observer: ApplicationObserver<SystemObserver>
    private var observerTokens: [ApplicationObserver<SystemObserver>.ObserverToken] = []
    public init(
        element: SystemElement,
        observer: ApplicationObserver<SystemObserver>
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        Self.logger.info("\(#function) \(self.element)")
        observerTokens.append(try await observer.add(
            element: element,
            notification: .selectedChildrenChanged,
            handler: isolated(action: List.selectedChildrenChanged)
        ))
    }
    public func stop() async throws {
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {}
        observerTokens.removeAll()
    }
    private func selectedChildrenChanged(
        element: SystemElement,
        userInfo: [String:Any]
    ) async {
        Self.logger.info("\(#function) \(element)")
    }
}
