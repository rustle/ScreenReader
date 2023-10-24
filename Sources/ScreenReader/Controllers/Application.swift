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
    public let element: ElementType
    public var identifier: AnyHashable {
        element
    }

    private var runState: RunState = .stopped
    private var observer: ApplicationObserver<ObserverType>?
    private var observerTasks: [Task<Void, any Error>] = []
    private var focus: [Controller] = []
    private let output: Output
    private var observerFactory: () async throws -> ApplicationObserver<ObserverType>
    private var controllerFactory: ControllerFactory<ObserverType>
    private var hierarchy: ControllerHierarchy<ObserverType>?
    private let jobs: AsyncStream<Output.Job>
    private let jobsContinuation: AsyncStream<Output.Job>.Continuation
    private var jobsTask: Task<Void, any Error>?
    private var logger: Logger {
        Loggers.Controller.application
    }

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
        (jobs, jobsContinuation) = AsyncStream<Output.Job>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
    }
    public func start() async throws {
        logger.debug("\(self.element)")
        guard runState == .stopped else { return }
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
            logger.debug("\(error.localizedDescription)")
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
            logger.debug("\(error.localizedDescription)")
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        for window in try element.windows() {
            do {
                try await hierarchy.controller(
                    element: window,
                    output: jobsContinuation,
                    observer: observer
                )
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }
        precondition(jobsTask == nil)
        jobsTask = Task(priority: .userInitiated) {
            for await job in jobs {
                try await output.submit(job: job)
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
        logger.debug("\(self.element)")
        guard runState == .running else { return }
        guard let observer = observer else { return }
        try await observer.stop()
        self.observer = nil
        observerTasks = []
        jobsTask?.cancel()
        jobsTask = nil
    }
    private func windowCreated(
        window: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(window)")
        do {
            try await focus()
        } catch {
            logger.error("\(window.description)")
        }
    }
    private func focusedWindowChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(element)")
        do {
            try await focus()
        } catch {
            logger.error("\(element.description)")
        }
    }
    private func focusedUIElementChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(element.description)")
        do {
            try await focus()
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    public func focus() async throws {
        logger.debug("\(self.element)")
        guard let observer else { return }
        guard let hierarchy else { return }
        do {
            let focusedUIElement = try element.focusedUIElement()
            focus = try await hierarchy.focus(
                application: element,
                element: focusedUIElement,
                output: jobsContinuation,
                observer: observer
            )
            try await focus.last?.focus()
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
}

extension Application {
    fileprivate static func controller(
        element: ElementType,
        output: AsyncStream<Output.Job>.Continuation,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Controller {
        switch try element.role() {
        case .button:
            try await Button(
                element: element,
                output: output,
                observer: observer
            )
        case .comboBox:
            try await ComboBox(
                element: element,
                output: output,
                observer: observer
            )
        case .group:
            try await Group(
                element: element,
                output: output,
                observer: observer
            )
        case .list:
            try await List(
                element: element,
                output: output,
                observer: observer
            )
        case .table:
            try await Table(
                element: element,
                output: output,
                observer: observer
            )
        case .textField:
            try await TextField(
                element: element,
                output: output,
                observer: observer
            )
        case .textArea:
            try await TextArea(
                element: element,
                output: output,
                observer: observer
            )
        case .webArea:
            try await WebArea(
                element: element,
                output: output,
                observer: observer
            )
        case .window:
            try await Window(
                element: element,
                output: output,
                observer: observer
            )
        default:
            try await Unknown(
                element: element,
                output: output,
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
            controllerFactory: Application.controller(element:output:observer:)
        )
    }
}
