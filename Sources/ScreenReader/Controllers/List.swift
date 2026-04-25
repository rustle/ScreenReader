//
//  List.swift
//  
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os
import RunLoopExecutor

public actor List<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.Controller.list
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
        do {
            observerTasks.append(try await add(
                notification: .selectedChildrenChanged,
                handler: target(action: List<ObserverType>.selectedChildrenChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        runState = .running
        await selectedChildrenChanged(
            element: element,
            userInfo: nil
        )
    }
    public func stop() async throws {
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
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
        guard !payloads.isEmpty else { return }
        output.yield(.init(
            options: [],
            identifier: "",
            payloads: payloads
        ))
    }
    private func selectedChildrenChanged(
        element: ElementType,
        userInfo: [String:ObserverElementInfoValue]?
    ) async {
        do {
            let selected = try element.selectedChildren()
            let titles = selected
                .compactMap {
                    try? $0.title()
                }
                .filter {
                    !$0.isEmpty
                }
            guard !titles.isEmpty else { return }
            let text = titles.count == 1
                ? titles[0]
                : "\(titles.joined(separator: ", ")), \(selected.count) items"
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

extension List: ObserverHosting {}
