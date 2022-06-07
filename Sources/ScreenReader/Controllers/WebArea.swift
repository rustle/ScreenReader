//
//  WebArea.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os
import TargetAction

public final class WebArea<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType

    private var logger: Logger {
        Loggers.Controller.webArea
    }

    let observer: ApplicationObserver<ObserverType>
    private var observerTasks: [Task<Void, any Error>] = []

    private var runState: RunState = .stopped

    public init(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        guard runState == .stopped else { return }
        logger.info("\(#function) \(self.element)")
        do {
            observerTasks.append(try await add(
                notification: .selectedTextChanged,
                handler: TargetAction.target(
                    self,
                    action: WebArea<ObserverType>.selectedTextChanged
                )
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
    }
    public func stop() async throws {
        logger.info("\(#function) \(self.element)")
        observerTasks.cancel()
    }
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.info("\(#function) \(element) \(String(describing: userInfo))")
    }
}

extension WebArea: ObserverHosting {}
