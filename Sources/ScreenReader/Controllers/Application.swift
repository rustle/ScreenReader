//
//  Application.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa
import os

public enum ApplicationError: Error {
    case observerError(ObserverError)
}

public actor Application<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement

    private var logger: Logger {
        Loggers.Controller.application
    }

    public let element: ElementType

    private var observer: ApplicationObserver<ObserverType>?
    private var observerTasks: [Task<Void, any Error>] = []

    private var focus: [Controller] = []

    private let output: Output
    private var observerFactory: () async throws -> ApplicationObserver<ObserverType>
    private var controllerFactory: ControllerFactory<ObserverType>
    private var hierarchy: ControllerHierarchy<ObserverType>?

    public init(
        element: ElementType,
        output: Output,
        observerFactory: @escaping () async throws -> ApplicationObserver<ObserverType>,
        controllerFactory: @escaping ControllerFactory<ObserverType>
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
            observerTasks.append(try await Self.add(
                observer: observer,
                element: element,
                notification: .windowCreated,
                handler: target(action: Application.windowCreated)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        do {
            observerTasks.append(try await Self.add(
                observer: observer,
                element: element,
                notification: .focusedWindowChanged,
                handler: target(action: Application.focusedWindowChanged)
            ))
        } catch let error as ControllerObserverError {
            switch error {
            case .notificationUnsupported:
                break;
            default:
                logger.info("\(error.localizedDescription)")
            }
        } catch {
            logger.error("\(#line):\(error.localizedDescription)")
        }
        for window in try element.windows() {
            do {
                try await hierarchy.controller(
                    element: window,
                    observer: observer
                )
            } catch {
                logger.error("\(#line):\(error.localizedDescription)")
            }
        }
        do {
            await focusedUIElementChanged(
                element: try element.focusedUIElement(),
                userInfo: nil
            )
        } catch ElementError.noValue {
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    public func stop() async throws {
        guard let observer = observer else { return }
        try await observer.stop()
        self.observer = nil
        observerTasks = []
    }
    private func windowCreated(
        window: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(type(of: self)).\(#function):\(#line) \(window)")
        do {
            try await focus()
        } catch {
            logger.error("\(type(of: self)).\(#function):\(#line) \(window.description)")
        }
    }
    private func focusedWindowChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(type(of: self)).\(#function):\(#line) \(element)")
        do {
            try await focus()
        } catch {
            logger.error("\(type(of: self)).\(#function):\(#line) \(element.description)")
        }
    }
    private func focusedUIElementChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(type(of: self)).\(#function):\(#line) \(element.description)")
        do {
            try await focus()
        } catch {
            logger.error("\(type(of: self)).\(#function):\(#line) \(error.localizedDescription)")
        }
    }
    public func focus() async throws {
        logger.debug("\(type(of: self)).\(#function):\(#line) \(self.element)")
        guard let observer else { return }
        guard let hierarchy else { return }
        do {
            let focusedUIElement = try element.focusedUIElement()
            focus = try await hierarchy.focus(
                application: element,
                element: focusedUIElement,
                observer: observer
            )
            try await focus.last?.focus()
        } catch {
            logger.error("\(type(of: self)).\(#function):\(#line) \(error.localizedDescription)")
        }
    }
}

extension Application {
    fileprivate static func controller(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Controller {
        switch try element.role() {
        case .button:
            try await Button(
                element: element,
                observer: observer
            )
        case .comboBox:
            try await ComboBox(
                element: element,
                observer: observer
            )
        case .group:
            try await Group(
                element: element,
                observer: observer
            )
        case .list:
            try await List(
                element: element,
                observer: observer
            )
        case .table:
            try await Table(
                element: element,
                observer: observer
            )
        case .textField:
            try await TextField(
                element: element,
                observer: observer
            )
        case .textArea:
            try await TextArea(
                element: element,
                observer: observer
            )
        case .webArea:
            try await WebArea(
                element: element,
                observer: observer
            )
        case .window:
            try await Window(
                element: element,
                observer: observer
            )
        default:
            try await Unknown(
                element: element,
                observer: observer
            )
        }
    }
}

extension Application where ObserverType == SystemObserver {
    public init(
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
