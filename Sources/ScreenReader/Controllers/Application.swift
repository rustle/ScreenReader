//
//  Application.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa
import os

public enum ApplicationError: Error {
    case observerError(ObserverError)
}

public actor Application<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
    private var observer: ApplicationObserver<ObserverType>?
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []
    private struct ControllerContext {
        let token: ApplicationObserver<ObserverType>.ObserverToken
        let controller: Controller
    }
    private var controllers: [ElementType:ControllerContext] = [:]
    private var focusedUIElement: Controller?

    private var observerFactory: () async throws -> ApplicationObserver<ObserverType>
    private var controllerFactory: (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller

    public init(
        element: ElementType,
        observerFactory: @escaping () async throws -> ApplicationObserver<ObserverType>,
        controllerFactory: @escaping (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller
    ) async throws {
        self.element = element
        self.observerFactory = observerFactory
        self.controllerFactory = controllerFactory
    }
    public func start() async throws {
        let observer:ApplicationObserver<ObserverType>
        do {
            observer = try await observerFactory()
            try await observer.start()
        } catch let error as ObserverError {
            throw ApplicationError.observerError(error)
        } catch {
            throw error
        }
        self.observer = observer
        do {
            observerTokens.append(try await observer.add(
                element: element,
                notification: .windowCreated,
                handler: isolated(action: Application.windowCreated)
            ))
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
        do {
            observerTokens.append(try await observer.add(
                element: element,
                notification: .focusedWindowChanged,
                handler: isolated(action: Application.focusedWindowChanged)
            ))
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
        for window in try element.windows() {
            do {
                try await add(window: window)
            } catch {
                Loggers.application.error("\(error.localizedDescription)")
            }
        }
    }
    public func stop() async throws {
        guard let observer = observer else { return }
        try await observer.stop()
        self.observer = nil
    }
    private func windowCreated(
        window: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.application.info("\(#function) \(window)")
        do {
            try await self.add(window: window)
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
    }
    private func uiElementDestroyed(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.application.info("\(#function) \(element)")
        do {
            guard let observer = observer else { return }
            guard let context = controllers.removeValue(forKey: element) else { return }
            try await observer.remove(token: context.token)
            try await context.controller.stop()
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
    }
    private func focusedWindowChanged(
        window: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.application.info("\(#function) \(window)")
    }
    private func focusedUIElementChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        guard let observer = observer else { return }
        Loggers.application.info("\(#function) \(element.debugDescription)")
        do {
            try await focusedUIElement?.stop()
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
        do {
            focusedUIElement = try await Self.controller(
                element: element,
                observer: observer
            )
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
        do {
            try await focusedUIElement?.start()
            try await focusedUIElement?.focus()
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
    }
    private func add(window: ElementType) async throws {
        guard let observer = observer else { return }
        let token = try await observer.add(
            element: element,
            notification: .uiElementDestroyed,
            handler: isolated(action: Application.uiElementDestroyed)
        )
        let windowController = try await Window(
            element: window,
            observer: observer
        )
        controllers[window] = .init(
            token: token,
            controller: windowController
        )
        try await windowController.start()
    }
}

extension Application {
    public static func controller(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Controller {
        let role = try element.role()
        switch role {
        case .button:
            return try await Button(
                element: element,
                observer: observer
            )
        case .comboBox:
            return try await ComboBox(
                element: element,
                observer: observer
            )
        case .list:
            return try await List(
                element: element,
                observer: observer
            )
        case .table:
            return try await Table(
                element: element,
                observer: observer
            )
        case .textArea:
            return try await TextArea(
                element: element,
                observer: observer
            )
        case .window:
            return try await Window(
                element: element,
                observer: observer
            )
        default:
            return try await Unknown(
                element: element,
                observer: observer
            )
        }
    }
}

extension Application where ObserverType == SystemObserver {
    public convenience init(processIdentifier: pid_t) async throws {
        try await self.init(
            element: try .application(processIdentifier: processIdentifier),
            observerFactory: { .init(observer: try .init(processIdentifier: processIdentifier)) },
            controllerFactory: Application.controller(element:observer:)
        )
    }
}
