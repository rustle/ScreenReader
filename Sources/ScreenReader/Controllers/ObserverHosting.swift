//
//  ObserverHosting.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa

protocol ObserverHosting: Controller {
    associatedtype ObserverType: Observer where ObserverType.ObserverElement: Hashable
    typealias ElementType = ObserverType.ObserverElement
    var element: ElementType { get }
    var observer: ApplicationObserver<ObserverType> { get }
    func add(
        notification: NSAccessibility.Notification,
        handler: @escaping (ElementType, [String:Any]?) async -> Void
    ) async throws -> ApplicationObserver<ObserverType>.ApplicationObserverToken
}

extension ObserverHosting {
    func add(
        notification: NSAccessibility.Notification,
        handler: @escaping (ElementType, [String:Any]?) async -> Void
    ) async throws -> ApplicationObserver<ObserverType>.ApplicationObserverToken {
        try await Self.add(
            observer: observer,
            element: element,
            notification: notification,
            handler: handler
        )
    }
    func remove(tokens: [ApplicationObserver<ObserverType>.ApplicationObserverToken]) async throws {
        var errors = [Error]()
        for observerToken in tokens {
            do {
                try await observer.remove(token: observerToken)
            } catch {
                errors.append(error)
            }
        }
        guard errors.isEmpty else {
            throw ControllerObserverError.multiple(errors)
        }
    }
}
