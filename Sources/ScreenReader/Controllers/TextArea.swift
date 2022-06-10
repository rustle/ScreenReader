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
        Loggers.Controller.textArea.info("\(#function) \(self.element)")
        do {
            observerTokens.append(try await add(
                notification: .valueChanged,
                handler: target(action: TextArea<ObserverType>.valueChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.textArea.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        do {
            observerTokens.append(try await add(
                notification: .selectedTextChanged,
                handler: target(action: TextArea<ObserverType>.selectedTextChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.textArea.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
    }
    public func focus() async throws {
        Loggers.Controller.textArea.info("\(#function) \(self.element)")
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
        userInfo: [String:Any]?
    ) async {
        //Loggers.Controller.textArea.info("\(#function) \(element)")
    }
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        //Loggers.Controller.textArea.info("\(#function) \(element)")
    }
}

extension TextArea: ObserverHosting {}
