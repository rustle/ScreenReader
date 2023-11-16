//
//  ObserverHosting.swift
//  
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa

protocol ObserverHosting: Controller {
    associatedtype ObserverType: Observer where ObserverType.ObserverElement: Hashable
    typealias ElementType = ObserverType.ObserverElement
    var element: ElementType { get }
    var observer: ApplicationObserver<ObserverType> { get }
    @Sendable
    func add(
        notification: NSAccessibility.Notification,
        handler: @escaping @Sendable (ElementType, [String:Sendable]?) async -> Void
    ) async throws -> Task<Void, any Error>
}

extension ObserverHosting {
    @Sendable
    func add(
        notification: NSAccessibility.Notification,
        handler: @escaping @Sendable (ElementType, [String:Sendable]?) async -> Void
    ) async throws -> Task<Void, any Error> {
        try await Self.add(
            observer: observer,
            element: element,
            notification: notification,
            handler: handler
        )
    }
}
