//
//  WebArea.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os
import TargetAction

public actor WebArea<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
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
        Loggers.Controller.webArea
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
                notification: .selectedTextChanged,
                handler: target(uncheckedAction: WebArea<ObserverType>.selectedTextChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
    }
    public func stop() async throws {
        logger.debug("\(self.element)")
        observerTasks = []
    }
    public func focus() async throws {
    }
    @Sendable
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:Sendable]?
    ) async {
        logger.debug("\(element) \(String(describing: userInfo))")
    }
}

extension WebArea: ObserverHosting {}
