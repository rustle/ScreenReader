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
        handler: @escaping (ObserverType.ObserverElement, [String:Any]?) async -> Void
    ) async throws -> ApplicationObserver<ObserverType>.ApplicationObserverToken {
        return try await Self.add(
            observer: observer,
            element: element,
            notification: notification,
            handler: handler
        )
    }
}
