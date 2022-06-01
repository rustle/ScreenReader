//
//  ControllerHierarchy.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation

actor ControllerHierarchy<ObserverType: AccessibilityElement.Observer> where ObserverType.ObserverElement: Hashable {
    typealias ElementType = ObserverType.ObserverElement
    private struct ControllerContext {
        let task: Task<Void, any Error>?
        let controller: Controller
    }
    private var controllers: [ElementType:ControllerContext] = [:]
    private let application: Application<ObserverType>
    private let controllerFactory: (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller
    private let observer: ApplicationObserver<ObserverType>
    private var observerTasks: Set<Task<Void, any Error>> = .init()
    init(
        application: Application<ObserverType>,
        observer: ApplicationObserver<ObserverType>,
        controllerFactory: @escaping (ElementType, ApplicationObserver<ObserverType>) async throws -> Controller
    ) async throws {
        self.application = application
        self.observer = observer
        self.controllerFactory = controllerFactory
    }
    private func uiElementDestroyed(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.hierarchy.info("\(#function) \(element)")
        guard let context = controllers.removeValue(forKey: element) else { return }
        if let task = context.task {
            task.cancel()
            observerTasks.remove(task)
        }
        do {
            try await context.controller.stop()
        } catch {
            Loggers.hierarchy.error("\(error.localizedDescription)")
        }
    }
    @discardableResult
    func controller(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws -> Controller {
        if let context = controllers[element] {
            return context.controller
        }
        var task: Task<Void, any Error>?
        do {
            switch try element.role() {
            case .window:
                fallthrough
            case .webArea:
                let stream = try await observer.stream(
                    element: element,
                    notification: .uiElementDestroyed
                )
                let action = target(action: ControllerHierarchy<ObserverType>.uiElementDestroyed)
                let t = Task(priority: .userInitiated) {
                    for try await notification in stream {
                        await action(
                            notification.element,
                            notification.info
                        )
                    }
                }
                observerTasks.insert(t)
                task = t
            default:
                break
            }
        } catch {}
        let controller = try await controllerFactory(
            element,
            observer
        )
        controllers[element] = .init(
            task: task,
            controller: controller
        )
        return controller
    }
}
