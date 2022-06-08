//
//  WebArea.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation

public actor WebArea<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
