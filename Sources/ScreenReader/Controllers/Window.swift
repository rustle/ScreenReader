//
//  Window.swift
//  
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Window<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.Controller.window
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
        runState = .running
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
}

extension Window: ObserverHosting {}
