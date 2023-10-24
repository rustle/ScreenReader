//
//  Table.swift
//  
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa
import TargetAction
import os

public actor Table<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
    public var identifier: AnyHashable {
        element
    }

    let observer: ApplicationObserver<ObserverType>

    private var observerTasks: [Task<Void, any Error>] = []
    private var runState: RunState = .stopped
    private let output: AsyncStream<Output.Job>.Continuation
    private var logger: Logger {
        Loggers.Controller.table
    }

    public init(
        element: ElementType,
        output: AsyncStream<Output.Job>.Continuation,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.output = output
        self.observer = observer
    }
    public func start() async throws {
        logger.debug("\(self.element)")
        guard runState == .stopped else { return }
        try await _add(
            notification: .selectedRowsChanged,
            handler: target(action: Table<ObserverType>.selectionChanged)
        )
        try await _add(
            notification: .selectedColumnsChanged,
            handler: target(action: Table<ObserverType>.selectionChanged)
        )
        runState = .running
        await selectionChanged(
            element: element,
            userInfo: nil
        )
    }
    private func _add(
        notification: NSAccessibility.Notification,
        handler: @escaping (ObserverType.ObserverElement, [String : Any]?) async -> Void
    ) async throws {
        do {
            observerTasks.append(try await add(
                notification: notification,
                handler: handler
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
    }
    public func focus() async throws {
        logger.debug("\(self.element)")
    }
    public func stop() async throws {
        logger.debug("\(self.element)")
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    private func selectionChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(self.element)")
        do {
            let cells = try element.selectedCells()
            logger.debug("\(cells)")
        } catch {
            logger.debug("\(error.localizedDescription)")
        }
    }
}

extension Table: ObserverHosting {}
