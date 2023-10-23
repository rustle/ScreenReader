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

    private var logger: Logger {
        Loggers.Controller.textField
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
        logger.debug("\(type(of: self)).\(#function):\(#line) \(self.element)")
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
    public func focus() async throws {
        logger.debug("\(type(of: self)).\(#function) \(self.element)")
    }
    public func stop() async throws {
        logger.debug("\(type(of: self)).\(#function) \(self.element)")
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(type(of: self)).\(#function) \(self.element)")
    }
    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(type(of: self)).\(#function) \(self.element)")
    }
}

extension TextField: ObserverHosting {}
