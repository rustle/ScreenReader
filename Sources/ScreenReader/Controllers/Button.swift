//
//  Button.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation

public actor Button<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.Controller.button.info("\(#function) \(self.element)")
        do {
            observerTokens.append(try await add(
                notification: .valueChanged,
                handler: isolated(action: Button<ObserverType>.valueChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.button.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
    }
    public func focus() async throws {
        Loggers.Controller.button.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {
            Loggers.Controller.button.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.Controller.button.info("\(#function) \(element)")
    }
}

extension Button: ObserverHosting {}
