//
//  TextArea.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation

public actor TextArea<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.textArea.info("\(#function) \(self.element)")
        observerTokens.append(try await observer.add(
            element: element,
            notification: .valueChanged,
            handler: isolated(action: TextArea<ObserverType>.valueChanged)
        ))
        observerTokens.append(try await observer.add(
            element: element,
            notification: .selectedTextChanged,
            handler: isolated(action: TextArea<ObserverType>.selectedTextChanged)
        ))
    }
    public func focus() async throws {
        Loggers.textArea.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {}
        observerTokens.removeAll()
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:Any]
    ) async {
        //Loggers.textArea.info("\(#function) \(element)")
    }
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:Any]
    ) async {
        //Loggers.textArea.info("\(#function) \(element)")
    }
}

extension TextArea: ObserverHosting {}
