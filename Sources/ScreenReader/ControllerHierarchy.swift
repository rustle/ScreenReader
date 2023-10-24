//
//  ControllerHierarchy.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public typealias ControllerFactory<ObserverType: AccessibilityElement.Observer> = (
    ObserverType.ObserverElement,
    AsyncStream<Output.Job>.Continuation,
    ApplicationObserver<ObserverType>
) async throws -> Controller where ObserverType.ObserverElement: Hashable

actor ControllerHierarchy<ObserverType: AccessibilityElement.Observer> where ObserverType.ObserverElement: Hashable {
    typealias ElementType = ObserverType.ObserverElement
    private struct ControllerContext {
        let task: Task<Void, any Error>?
        let controller: Controller
    }
    private var logger: Logger {
        Loggers.hierarchy
    }
    private var controllers: [ElementType:ControllerContext] = [:]
    private let application: Application<ObserverType>
    private let controllerFactory: ControllerFactory<ObserverType>
    private let observer: ApplicationObserver<ObserverType>
    private var observerTasks: Set<Task<Void, any Error>> = .init()
    init(
        application: Application<ObserverType>,
        observer: ApplicationObserver<ObserverType>,
        controllerFactory: @escaping ControllerFactory<ObserverType>
    ) async throws {
        self.application = application
        self.observer = observer
        self.controllerFactory = controllerFactory
    }
    private func uiElementDestroyed(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.debug("\(element)")
        guard let context = controllers.removeValue(forKey: element) else { return }
        if let task = context.task {
            task.cancel()
            observerTasks.remove(task)
        }
        do {
            try await context.controller.stop()
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    @discardableResult
    func focus(
        application: ElementType,
        element: ElementType,
        output: AsyncStream<Output.Job>.Continuation,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> [Controller] {
        logger.debug("\(element)")
        do {
            var newFocus = [Controller]()
            var current: ElementType?
            do {
                current = try element.focusedUIElement()
            } catch {
                logger.error("\(error.localizedDescription)")
                current = element
            }
            while current != nil, current != application {
                newFocus.append(try await controller(
                    element: current!,
                    output: output,
                    observer: observer
                ))
                current = try? current?.parent()
            }
            for controller in newFocus {
                try await controller.start()
            }
            return newFocus.reversed()
        } catch {
            logger.error("\(error.localizedDescription)")
            return []
        }
    }
    @discardableResult
    func controller(
        element: ElementType,
        output: AsyncStream<Output.Job>.Continuation,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Controller {
        if let context = controllers[element] {
            logger.debug("Cached controller for \(element)")
            return context.controller
        }
        logger.debug("\(element)")
        let task: Task<Void, Error>?
        do {
            task = try await observerStreamTask(
                element: element,
                observer: observer
            )
        } catch let error as ControllerObserverError {
            switch error {
            case .notificationUnsupported:
                break;
            default:
                logger.error("\(error.localizedDescription)")
            }
            task = nil
        } catch {
            logger.error("\(error.localizedDescription)")
            task = nil
        }
        let controller = try await controllerFactory(
            element,
            output,
            observer
        )
        controllers[element] = .init(
            task: task,
            controller: controller
        )
        return controller
    }
    private func observerStreamTask(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Task<Void, any Error> {
        let stream = try await observer.stream(
            element: element,
            notification: .uiElementDestroyed
        )
        let action = target(action: ControllerHierarchy<ObserverType>.uiElementDestroyed)
        let task: Task<Void, any Error> = Task(priority: .userInitiated) {
            for try await notification in stream {
                await action(
                    notification.element,
                    notification.info
                )
            }
        }
        observerTasks.insert(task)
        return task
    }
}
