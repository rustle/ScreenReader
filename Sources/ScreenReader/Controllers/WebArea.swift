//
//  WebArea.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor WebArea<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType

    private var logger: Logger {
        Loggers.Controller.webArea
    }

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
        Loggers.Controller.webArea.info("\(#function) \(self.element)")
        do {
            observerTokens.append(try await add(
                notification: .selectedTextChanged,
                handler: target(action: WebArea<ObserverType>.selectedTextChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.webArea.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
    }
    public func stop() async throws {
        Loggers.Controller.webArea.info("\(#function) \(self.element)")
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {
            Loggers.Controller.webArea.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.Controller.webArea.info("\(#function) \(element) \(String(describing: userInfo))")
    }
}

extension WebArea: ObserverHosting {}
