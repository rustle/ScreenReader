//
//  TextField.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import TargetAction
import os

public actor TextField<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.Controller.textField
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
                notification: .valueChanged,
                handler: target(action: TextField<ObserverType>.valueChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        do {
            observerTasks.append(try await add(
                notification: .selectedTextChanged,
                handler: target(action: TextField<ObserverType>.selectedTextChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        runState = .running
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
        if let value = (try? element.value()) as? String, !value.isEmpty {
            parts.append(value)
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
    public func stop() async throws {
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:ObserverElementInfoValue]?
    ) async {
        guard let value = (try? element.value()) as? String else { return }
        output.yield(.init(
            options: [],
            identifier: "",
            payloads: [.speech(value, nil)]
        ))
    }
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:ObserverElementInfoValue]?
    ) async {
    }
}

extension TextField: ObserverHosting {}
