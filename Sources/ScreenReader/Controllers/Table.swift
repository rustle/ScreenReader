//
//  Table.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Table<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
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
        Loggers.table.info("\(#function) \(self.element)")
        observerTokens.append(try await observer.add(
            element: element,
            notification: .selectedRowsChanged,
            handler: isolated(action: Table<ObserverType>.selectedRowsChanged)
        ))
    }
    public func focus() async throws {
        Loggers.table.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {}
        observerTokens.removeAll()
    }
    private func selectedRowsChanged(
        element: ElementType,
        userInfo: [String:Any]
    ) async {
        Loggers.table.info("\(#function) \(element)")
    }
}
