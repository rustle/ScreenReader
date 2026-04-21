//
//  Application.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
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

    public nonisolated let unownedExecutor: UnownedSerialExecutor

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
    nonisolated let executor: RunLoopExecutor
    private var logger: Logger {
        Loggers.Controller.application
    }

    public init(
        element: ElementType,
        output: Output,
        // RunLoopExecutor is @unchecked Sendable for now
        // so we need sending (for now)
        executor: sending RunLoopExecutor,
        observerFactory: @escaping () async throws -> ApplicationObserver<ObserverType>,
        controllerFactory: @escaping ControllerFactory<ObserverType>
    ) async throws {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
        self.executor = executor
        self.element = element
        self.output = output
        self.observerFactory = observerFactory
        self.controllerFactory = controllerFactory
        (jobs, jobsContinuation) = AsyncStream<Output.Job>
            .makeStream(bufferingPolicy: .bufferingNewest(1))
    }
    public func start() async throws {
        guard runState == .stopped else { return }
        do {
            try element.setEnhancedUserInterface(true)
            logger.info("Set Enhanced User Interface For \(self.elementDescriptionForLogging)")
        } catch ElementError.notImplemented {
        } catch {
            logger.error("Error Setting Enhanced User Interface For \(self.elementDescriptionForLogging)")
        }
        let observer: ApplicationObserver<ObserverType>
        let hierarchy: ControllerHierarchy<ObserverType>
        do {
            observer = try await observerFactory()
            hierarchy = try await ControllerHierarchy(
                application: self,
                observer: observer,
                controllerFactory: controllerFactory,
                executor: executor
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
        do {
            observerTasks.append(try await Self.add(
                observer: observer,
                element: element,
                notification: .focusedUIElementChanged,
                handler: target(action: Application.focusedUIElementChanged)
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
                    bufferedOutput: jobsContinuation,
                    directOutput: output
                )
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }
        precondition(jobsTask == nil)
        jobsTask = Task(priority: .medium) {
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
        runState = .running
    }
    public func stop() async throws {
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
        userInfo: [String:ObserverElementInfoValue]?
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
        userInfo: [String:ObserverElementInfoValue]?
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
        userInfo: [String:ObserverElementInfoValue]?
    ) async {
        logger.debug("\(element.description)")
        do {
            try await focus()
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    public func focus() async throws {
        guard let hierarchy else { return }
        do {
            let focusedUIElement = try element.focusedUIElement()
            focus = try await hierarchy.focus(
                application: element,
                element: focusedUIElement,
                bufferedOutput: jobsContinuation,
                directOutput: output
            )
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }

    public func dispatch(command: ScreenReaderCommand) async {
        guard let hierarchy else {
            return
        }
        await hierarchy.dispatch(
            command: command,
            bufferedOutput: jobsContinuation,
            directOutput: output
        )
    }
}

extension Application {
    @Sendable
    fileprivate static func controller(
        element: ElementType,
        bufferedOutput: AsyncStream<Output.Job>.Continuation,
        directOutput: any OutputContext,
        observer: ApplicationObserver<ObserverType>,
        executor: RunLoopExecutor
    ) async throws -> Controller {
        switch try element.role() {
        case .button:
            try await Button(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        case .comboBox:
            try await ComboBox(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        case .group:
            try await Group(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        case .list:
            try await List(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        case .table:
            try await Table(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        case .textField:
            try await TextField(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        case .textArea:
            try await TextArea(
                element: element,
                output: .init(
                    directOutput: directOutput,
                    bufferedOutput: bufferedOutput
                ),
                observer: observer,
                executor: executor
            )
        case .webArea:
            try await WebArea(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        case .window:
            try await Window(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        default:
            try await Unknown(
                element: element,
                output: bufferedOutput,
                observer: observer,
                executor: executor
            )
        }
    }
}

extension Application where ObserverType == SystemObserver {
    public init(
        processIdentifier: pid_t,
        output: Output,
        executor: RunLoopExecutor
    ) async throws {
        try await self.init(
            element: try .application(processIdentifier: processIdentifier),
            output: output,
            executor: executor,
            observerFactory: {
                .init(
                    observer: try .init(
                        processIdentifier: processIdentifier,
                        executor: executor
                    )
                )
            },
            controllerFactory: { element, bufferedOutput, directOutput, observer in
                try await Application.controller(
                    element: element,
                    bufferedOutput: bufferedOutput,
                    directOutput: directOutput,
                    observer: observer,
                    executor: executor
                )
            }
        )
    }
}

extension Application {
    var elementDescriptionForLogging: String {
        let processIdentifierDescription: String
        do {
            let processIdentifier = try element.processIdentifier
            processIdentifierDescription = "(\(processIdentifier))"
        } catch {
            processIdentifierDescription = "(?)"
        }
        let description: String
        do {
            description = try element.title()
        } catch {
            do {
                description = try element.titleUIElement().title()
            } catch {
                description = element.debugDescription
            }
        }
        return "\(processIdentifierDescription) \(description)"
    }
}
