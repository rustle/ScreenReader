//
//  ComboBox.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation

public actor ComboBox<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
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
        Loggers.Controller.comboBox.info("\(#function) \(self.element)")
    }
    public func focus() async throws {
        Loggers.Controller.comboBox.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {
            Loggers.Controller.comboBox.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
}

extension ComboBox: ObserverHosting {}
