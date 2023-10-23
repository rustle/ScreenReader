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

    private var logger: Logger {
        Loggers.Controller.list
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
        logger.debug("\(type(of: self)).\(#function) \(self.element)")
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
        logger.debug("\(type(of: self)).\(#function) \(self.element)")
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    private func selectedChildrenChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(type(of: self)).\(#function) \(self.element)")
        do {
            let children = try element.selectedChildren()
            logger.debug("\(type(of: self)).\(#function) \(children)")
        } catch {
            logger.debug("\(type(of: self)).\(#function) \(error.localizedDescription)")
        }
    }
}

extension List: ObserverHosting {}
