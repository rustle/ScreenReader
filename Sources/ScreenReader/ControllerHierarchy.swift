//
//  ControllerHierarchy.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation

actor ControllerHierarchy<ObserverType: AccessibilityElement.Observer> where ObserverType.ObserverElement: Hashable {
    typealias ElementType = ObserverType.ObserverElement
    private struct ControllerContext {
        let token: ApplicationObserver<ObserverType>.ApplicationObserverToken?
        let controller: Controller
    }
    private var controllers: [ElementType:ControllerContext] = [:]
    private let application: Application<ObserverType>
    private let controllerFactory: (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller
    private let observer: ApplicationObserver<ObserverType>
    private var observerTokens: Set<ApplicationObserver<ObserverType>.ObserverToken> = .init()
    init(
        application: Application<ObserverType>,
        observer: ApplicationObserver<ObserverType>,
        controllerFactory: @escaping (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller
    ) async throws {
        self.application = application
        self.observer = observer
        self.controllerFactory = controllerFactory
    }
    private func uiElementDestroyed(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.hierarchy.info("\(#function) \(element)")
        guard let context = controllers.removeValue(forKey: element) else { return }
        if let token = context.token {
            do {
                try await observer.remove(token: token)
            } catch ObserverError.invalidUIElement {
            } catch {
                Loggers.hierarchy.error("\(error.localizedDescription)")
            }
            observerTokens.remove(token)
        }
        do {
            try await context.controller.stop()
        } catch {
            Loggers.hierarchy.error("\(error.localizedDescription)")
        }
    }
    @discardableResult
    func controller(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Controller {
        if let context = controllers[element] {
            return context.controller
        }
        var token: ApplicationObserver<ObserverType>.ApplicationObserverToken?
        do {
            if try element.role() == .window {
                let t = try await observer.add(
                    element: element,
                    notification: .uiElementDestroyed,
                    handler: target(action: ControllerHierarchy<ObserverType>.uiElementDestroyed)
                )
                observerTokens.insert(t)
                token = t
            }
        } catch {}
        let controller = try await controllerFactory(
            element,
            observer
        )
        controllers[element] = .init(
            token: token,
            controller: controller
        )
        return controller
    }
}
