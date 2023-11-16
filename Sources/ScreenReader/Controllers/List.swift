//
//  List.swift
//  
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor List<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.Controller.list
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
                notification: .selectedChildrenChanged,
                handler: target(uncheckedAction: List<ObserverType>.selectedChildrenChanged)
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
        logger.debug("\(self.element)")
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    public func focus() async throws {
        logger.debug("\(self.element)")
        var buffer = ["Focus"]
        if let title = try? element.title(), title.count > 0 {
            buffer.append(title)
        } else if let titleUIElement = try? element.titleUIElement(), let title = try? titleUIElement.title(), title.count > 0 {
            buffer.append(title)
        }
        if let roleDescription = try? element.roleDescription() {
            buffer.append(roleDescription)
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
                    .speech(buffer.joined(separator: ", "), nil)
                ]
            )
        )
    }
    private func selectedChildrenChanged(
        element: ElementType,
        userInfo: [String:Sendable]?
    ) async {
        logger.debug("\(self.element)")
        do {
            let children = try element.selectedChildren()
            logger.debug("Selected Children \(children)")
        } catch {
            logger.debug("\(error.localizedDescription)")
        }
    }
}

extension List: ObserverHosting {}
