//
//  Table.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Table: Controller {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "Table")
    private let element: SystemElement
    private let observer: ApplicationObserver
    private var observerTokens: [ApplicationObserver.ObserverToken] = []
    public init(
        element: SystemElement,
        observer: ApplicationObserver
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        Self.logger.info("\(#function) \(self.element)")
        observerTokens.append(try await observer.add(
            element: element,
            notification: .selectedRowsChanged,
            handler: isolated(action: Table.selectedRowsChanged)
        ))
    }
    public func focus() async throws {
        Self.logger.info("\(#function) \(self.element)")
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
        element: SystemElement,
        userInfo: [String:Any]
    ) async {
        Self.logger.info("\(#function) \(element)")
    }
}
