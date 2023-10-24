//
//  Unknown.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Unknown<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.Controller.unknown
    }
#if DEBUG
    private var cachedDebugInfo: [String:Any]?
#endif // DEBUG

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
#if DEBUG
        if let element = element as? SystemElement {
            cachedDebugInfo = element.debugInfo
        } else {
            cachedDebugInfo = ["Description": element.description]
        }
#endif // DEBUG
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
    public func stop() async throws {
#if DEBUG
        if let cachedDebugInfo = cachedDebugInfo {
            logger.debug("\(self.element) \(cachedDebugInfo)")
        } else {
            logger.debug("\(self.element)")
        }
#else
        logger.debug("\(self.element)")
#endif // DEBUG
        observerTasks = []
    }
}

extension Unknown: ObserverHosting {}
