//
//  Table.swift
//  
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
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

    public nonisolated let unownedExecutor: UnownedSerialExecutor
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
        observer: ApplicationObserver<ObserverType>,
        executor: RunLoopExecutor
    ) async throws {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
        self.element = element
        self.output = output
        self.observer = observer
    }
    public func start() async throws {
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
        handler: @escaping @Sendable (ObserverType.ObserverElement, [String:ObserverElementInfoValue]?) async -> Void
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
    public func output(event: ControllerOutputEvent) async throws -> [Output.Job.Payload] {
        var parts = [String]()
        if let title = try? element.title(), !title.isEmpty {
            parts.append(title)
        } else if let titleUIElement = try? element.titleUIElement(), let title = try? titleUIElement.title(), !title.isEmpty {
            parts.append(title)
        }
        if let roleDescription = try? element.roleDescription() {
            parts.append(roleDescription)
        }
        guard !parts.isEmpty else { return [] }
        return [.speech(parts.joined(separator: ", "), nil)]
    }
    public func focus() async throws {
        let payloads = try await output(event: .focusIn)
        guard !payloads.isEmpty else {
            return
        }
        output.yield(.init(
            options: [],
            identifier: "",
            payloads: payloads
        ))
    }
    public func stop() async throws {
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    private func selectionChanged(
        element: ElementType,
        userInfo: [String:ObserverElementInfoValue]?
    ) async {
        do {
            let cells = try element.selectedCells()
            let titles = cells.compactMap { try? $0.title() }.filter { !$0.isEmpty }
            let text: String
            if !titles.isEmpty {
                text = titles.joined(separator: ", ")
            } else if !cells.isEmpty {
                text = "\(cells.count) cell\(cells.count == 1 ? "" : "s") selected"
            } else {
                return
            }
            output.yield(.init(
                options: [],
                identifier: "",
                payloads: [.speech(text, nil)]
            ))
        } catch {
            logger.debug("\(error.localizedDescription)")
        }
    }
}

extension Table: ObserverHosting {}
