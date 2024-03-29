//
//  TextField.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
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
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.output = output
        self.observer = observer
    }
    public func start() async throws {
        logger.debug("\(self.element)")
        guard runState == .stopped else { return }
        do {
            observerTasks.append(try await add(
                notification: .valueChanged,
                handler: target(uncheckedAction: TextField<ObserverType>.valueChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        do {
            observerTasks.append(try await add(
                notification: .selectedTextChanged,
                handler: target(uncheckedAction: TextField<ObserverType>.selectedTextChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        runState = .running
    }
    public func focus() async throws {
        logger.debug("\(self.element)")
        var buffer = [String]()
        buffer.reserveCapacity(3)
        if let title = try? element.title(), title.count > 0 {
            buffer.append(title)
        } else if let titleUIElement = try? element.titleUIElement(), let title = try? titleUIElement.title(), title.count > 0 {
            buffer.append(title)
        }
        if let roleDescription = try? element.roleDescription() {
            buffer.append(roleDescription) // 2
        }
        if let value = try? element.value() {
            if let string = value as? String {
                buffer.append(string)
            } else {
                logger.debug("\(String(describing: value))")
            }
        }
        output.yield(
            .init(
                options: [],
                identifier: "",
                payloads: [
                    .speech("Focus \(buffer.joined(separator: ", "))", nil)
                ]
            )
        )
    }
    public func stop() async throws {
        logger.debug("\(self.element)")
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:Sendable]?
    ) async {
        logger.debug("\(self.element)")
    }
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:Sendable]?
    ) async {
        logger.debug("\(self.element)")
    }
}

extension TextField: ObserverHosting {}
