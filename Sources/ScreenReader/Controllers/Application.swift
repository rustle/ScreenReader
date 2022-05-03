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
    public let element: ElementType
    private var observer: ApplicationObserver<ObserverType>?
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []
    private var focusedUIElement: Controller?
    private let output: Output
    private var observerFactory: () async throws -> ApplicationObserver<ObserverType>
    private var controllerFactory: (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller
    private var hierarchy: ControllerHierarchy<ObserverType>?

    public init(
        element: ElementType,
        output: Output,
        observerFactory: @escaping () async throws -> ApplicationObserver<ObserverType>,
        controllerFactory: @escaping (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller
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
                handler: isolated(action: Application.windowCreated)
            ))
        } catch let error as ControllerObserverError {
            Loggers.application.info("\(error.localizedDescription)")
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
        do {
            observerTokens.append(try await Self.add(
                observer: observer,
                element: element,
                notification: .focusedWindowChanged,
                handler: isolated(action: Application.focusedWindowChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.application.info("\(error.localizedDescription)")
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
        }
        for window in try element.windows() {
            do {
                try await hierarchy.controller(
                    element: window,
                    observer: observer
                )
            } catch {
                Loggers.application.error("\(error.localizedDescription)")
            }
        }
        do {
            await focusedUIElementChanged(
                element: try element.focusedUIElement(),
                userInfo: nil
            )
        } catch {
            Loggers.application.error("\(error.localizedDescription)")
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
        Loggers.application.info("\(#function):\(#line) \(window)")
        do {
            guard let hierarchy = hierarchy else { return }
            guard let observer = observer else { return }
            try await hierarchy.controller(
                element: window,
                observer: observer
            )
        } catch {
            Loggers.application.error("\(#function):\(#line) \(error.localizedDescription)")
        }
    }
    private func focusedWindowChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.application.info("\(#function):\(#line) \(element)")
        guard let observer = observer else { return }
        do {
            try await Self.controller(
                element: try element.focusedWindow(),
                observer: observer
            )
                .focus()
        } catch {
            Loggers.application.error("\(#function):\(#line) \(error.localizedDescription)")
        }
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
    public convenience init(
        processIdentifier: pid_t,
        output: Output
    ) async throws {
        try await self.init(
            element: try .application(processIdentifier: processIdentifier),
            output: output,
            observerFactory: { .init(observer: try .init(processIdentifier: processIdentifier)) },
            controllerFactory: Application.controller(element:observer:)
        )
    }
}
