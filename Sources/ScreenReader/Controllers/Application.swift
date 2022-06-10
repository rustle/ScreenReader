//
//  Application.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa

public enum ApplicationError: Error {
    case observerError(ObserverError)
}

public actor Application<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public typealias ControllerFactory = (
        ElementType,
        Application<ObserverType>,
        ApplicationObserver<ObserverType>
    ) async throws -> Controller

    public let element: ElementType
    private var observer: ApplicationObserver<ObserverType>?
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []
    private var focusedUIElement: Controller?
    private let output: Output
    private var observerFactory: () async throws -> ApplicationObserver<ObserverType>
    private var controllerFactory: ControllerFactory
    private var hierarchy: ControllerHierarchy<ObserverType>?

    public init(
        element: ElementType,
        output: Output,
        observerFactory: @escaping () async throws -> ApplicationObserver<ObserverType>,
        controllerFactory: @escaping ControllerFactory
    ) async throws {
        self.element = element
        self.output = output
        self.observerFactory = observerFactory
        self.controllerFactory = controllerFactory
    }
    public func start() async throws {
        let observer:ApplicationObserver<ObserverType>
        let hierarchy: ControllerHierarchy<ObserverType>
        do {
            observer = try await observerFactory()
            hierarchy = try await ControllerHierarchy(
                application: self,
                observer: observer,
                controllerFactory: controllerFactory
            )
            try await observer.start()
        } catch let error as ObserverError {
            throw ApplicationError.observerError(error)
        } catch {
            throw error
        }
        self.observer = observer
        self.hierarchy = hierarchy
        do {
            observerTokens.append(try await Self.add(
                observer: observer,
                element: element,
                notification: .windowCreated,
                handler: target(action: Application.windowCreated)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.application.info("\(error.localizedDescription)")
        } catch {
            Loggers.Controller.application.error("\(error.localizedDescription)")
        }
        do {
            observerTokens.append(try await Self.add(
                observer: observer,
                element: element,
                notification: .focusedWindowChanged,
                handler: target(action: Application.focusedWindowChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.application.info("\(error.localizedDescription)")
        } catch {
            Loggers.Controller.application.error("\(error.localizedDescription)")
        }
        for window in try element.windows() {
            do {
                try await hierarchy.controller(
                    element: window,
                    application: self,
                    observer: observer
                )
            } catch {
                Loggers.Controller.application.error("\(error.localizedDescription)")
            }
        }
        do {
            await focusedUIElementChanged(
                element: try element.focusedUIElement(),
                userInfo: nil
            )
        } catch {
            Loggers.Controller.application.error("\(error.localizedDescription)")
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
        Loggers.Controller.application.info("\(#function):\(#line) \(window)")
        do {
            guard let hierarchy = hierarchy else { return }
            guard let observer = observer else { return }
            try await hierarchy.controller(
                element: window,
                application: self,
                observer: observer
            )
        } catch {
            Loggers.Controller.application.error("\(#function):\(#line) \(error.localizedDescription)")
        }
    }
    private func focusedWindowChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.Controller.application.info("\(#function):\(#line) \(element)")
        guard let observer = observer else { return }
        do {
            try await Self.controller(
                element: try element.focusedWindow(),
                application: self,
                observer: observer
            )
                .focus()
        } catch {
            Loggers.Controller.application.error("\(#function):\(#line) \(error.localizedDescription)")
        }
    }
    private func focusedUIElementChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        guard let observer = observer else { return }
        Loggers.Controller.application.info("\(#function) \(element.description)")
        do {
            try await focusedUIElement?.stop()
        } catch {
            Loggers.Controller.application.error("\(error.localizedDescription)")
        }
        do {
            focusedUIElement = try await Self.controller(
                element: element,
                application: self,
                observer: observer
            )
        } catch {
            Loggers.Controller.application.error("\(error.localizedDescription)")
        }
        do {
            try await focusedUIElement?.start()
            try await focusedUIElement?.focus()
        } catch {
            Loggers.Controller.application.error("\(error.localizedDescription)")
        }
    }
}

extension Application {
    public static func controller(
        element: ElementType,
        application: Application<ObserverType>,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Controller {
        let role = try element.role()
        switch role {
        case .button:
            return try await Button(
                element: element,
                application: application,
                observer: observer
            )
        case .comboBox:
            return try await ComboBox(
                element: element,
                application: application,
                observer: observer
            )
        case .list:
            return try await List(
                element: element,
                application: application,
                observer: observer
            )
        case .table:
            return try await Table(
                element: element,
                application: application,
                observer: observer
            )
        case .textArea:
            return try await TextArea(
                element: element,
                application: application,
                observer: observer
            )
        case .webArea:
            return try await WebArea(
                element: element,
                application: application,
                observer: observer
            )
        case .window:
            return try await Window(
                element: element,
                application: application,
                observer: observer
            )
        default:
            return try await Unknown(
                element: element,
                application: application,
                observer: observer
            )
        }
    }
}

extension Application where ObserverType == SystemObserver {
    public convenience init(
        processIdentifier: pid_t,
        output: Output
    ) async throws {
        try await self.init(
            element: try .application(processIdentifier: processIdentifier),
            output: output,
            observerFactory: { .init(observer: try .init(processIdentifier: processIdentifier)) },
            controllerFactory: Application.controller(element:application:observer:)
        )
    }
}
