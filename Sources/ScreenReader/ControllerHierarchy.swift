//
//  ControllerHierarchy.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os
import RunLoopExecutor

public typealias ControllerFactory<ObserverType: AccessibilityElement.Observer> = @Sendable (
    ObserverType.ObserverElement,
    AsyncStream<Output.Job>.Continuation,
    any OutputContext,
    ApplicationObserver<ObserverType>
) async throws -> Controller where ObserverType.ObserverElement: Hashable

public actor ControllerHierarchy<ObserverType: AccessibilityElement.Observer> where ObserverType.ObserverElement: Hashable {
    typealias ElementType = ObserverType.ObserverElement

    // MARK: - Node

    private final class Node: @unchecked Sendable {
        let element: ElementType
        let controller: Controller
        weak var parent: Node?
        var children: [ElementType: Node] = [:]
        var destroyTask: Task<Void, any Error>?

        init(
            element: ElementType,
            controller: Controller
        ) {
            self.element = element
            self.controller = controller
        }
    }

    // MARK: - State

    public nonisolated let unownedExecutor: UnownedSerialExecutor

    private var nodes: [ElementType: Node] = [:]
    /// Coalesces concurrent creation requests for the same element.
    /// Between the guard check in getOrCreateNode and the point where we store the
    /// finished node in `nodes`, the actor can be re-entered at any `await`. Without
    /// this table a second caller would pass the guard, call observer.stream() again,
    /// receive the same cached unicast AsyncThrowingStream, and spawn a second
    /// iterating task.
    private var pendingNodes: [ElementType: Task<Node, any Error>] = [:]
    private var focusPath: [Node] = []
    private let application: Application<ObserverType>
    private let controllerFactory: ControllerFactory<ObserverType>
    private let observer: ApplicationObserver<ObserverType>
    private var logger: Logger {
        Loggers.hierarchy
    }

    // MARK: - Init

    public init(
        application: Application<ObserverType>,
        observer: ApplicationObserver<ObserverType>,
        controllerFactory: @escaping ControllerFactory<ObserverType>,
        executor: RunLoopExecutor
    ) async throws {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
        self.application = application
        self.observer = observer
        self.controllerFactory = controllerFactory
    }

    // MARK: - Focus

    /// Builds the focus chain for the given element, diffs against the previous chain,
    /// stops controllers that left, starts controllers that entered, emits output()
    /// payloads for ancestors at and after the divergence point, then calls focus() on the leaf.
    /// Returns the new chain (top-down) for the caller to cache.
    @discardableResult
    func focus(
        application applicationElement: ElementType,
        element: ElementType,
        bufferedOutput: AsyncStream<Output.Job>.Continuation,
        directOutput: any OutputContext
    ) async throws -> [Controller] {
        logger.debug("\(element.debugDescription)")

        // Build path bottom-up: leaf first, root last.
        var newPathBottomUp: [Node] = []
        do {
            var current: ElementType?
            do {
                current = try await element.focusedUIElement()
            } catch {
                current = element
            }
            while let c = current, c != applicationElement {
                newPathBottomUp.append(try await getOrCreateNode(
                    element: c,
                    bufferedOutput: bufferedOutput,
                    directOutput: directOutput
                ))
                current = try? await c.parent()
            }
        } catch {
            logger.error("\(error.localizedDescription)")
            return []
        }

        // Establish parent-child links among the newly created/visited nodes.
        // newPathBottomUp[0] is the leaf; newPathBottomUp[i+1] is its parent.
        for i in 0..<(newPathBottomUp.count - 1) {
            let childNode = newPathBottomUp[i]
            let parentNode = newPathBottomUp[i + 1]
            if childNode.parent !== parentNode {
                childNode.parent = parentNode
                parentNode.children[childNode.element] = childNode
                await childNode.controller.setParent(parentNode.controller)
            }
        }

        let newPath = newPathBottomUp.reversed() as [Node] // top-down

        // Diff against the previous focus path.
        let newElementSet = Set(newPath.map { $0.element })
        let oldElementSet = Set(focusPath.map { $0.element })

        for node in focusPath where !newElementSet.contains(node.element) {
            do {
                try await node.controller.unfocus()
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }
        for node in newPath where !oldElementSet.contains(node.element) {
            do {
                try await node.controller.start()
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }

        // Find the index at which the new path first diverges from the old path.
        var divergenceIndex = 0
        while divergenceIndex < focusPath.count,
              divergenceIndex < newPath.count,
              focusPath[divergenceIndex].element == newPath[divergenceIndex].element {
            divergenceIndex += 1
        }

        focusPath = newPath

        // Emit output() payloads for ancestor nodes from the divergence point up to
        // (but not including) the leaf. These give the user context when entering a new
        // window, group, or other container.
        if newPath.count > 1 {
            let ancestorEnd = newPath.count - 1
            if divergenceIndex < ancestorEnd {
                var ancestorPayloads: [Output.Job.Payload] = []
                for node in newPath[divergenceIndex..<ancestorEnd] {
                    do {
                        ancestorPayloads.append(contentsOf: try await node.controller.output(event: .focusThrough))
                    } catch {
                        logger.error("\(error.localizedDescription)")
                    }
                }
                if !ancestorPayloads.isEmpty {
                    bufferedOutput.yield(.init(
                        options: [.interrupt],
                        identifier: "",
                        payloads: ancestorPayloads
                    ))
                }
            }
        }

        // Call focus() on the leaf.
        if let leaf = newPath.last {
            do {
                try await leaf.controller.focus()
            } catch {
                logger.error("\(error.localizedDescription)")
            }
        }

        return newPath.map {
            $0.controller
        }
    }

    // MARK: - Command dispatch

    /// Routes a command to the appropriate controller.
    ///
    /// Tree-navigation commands are handled here using the current focus path.
    /// All other commands are forwarded to the leaf controller.
    func dispatch(
        command: ScreenReaderCommand,
        bufferedOutput: AsyncStream<Output.Job>.Continuation,
        directOutput: any OutputContext
    ) async {
        switch command {
        case .navigateOut:
            guard let leaf = focusPath.last,
                  let parent = leaf.parent else { return }
            do {
                try await self.focus(
                    application: application.element,
                    element: parent.element,
                    bufferedOutput: bufferedOutput,
                    directOutput: directOutput
                )
            } catch {
                logger.error("navigateOut: \(error.localizedDescription)")
            }
        case .navigateIn:
            guard let leaf = focusPath.last,
                  let firstChild = leaf.children.values.first else { return }
            do {
                try await self.focus(
                    application: application.element,
                    element: firstChild.element,
                    bufferedOutput: bufferedOutput,
                    directOutput: directOutput
                )
            } catch {
                logger.error("navigateIn: \(error.localizedDescription)")
            }
        case .navigateNext, .navigatePrevious:
            // Sibling navigation requires knowing the parent's child order from AX;
            // deferred until Element gains children()/indexOf() support.
            break
        default:
            if let leaf = focusPath.last {
                await leaf.controller.dispatch(command: command)
            }
        }
    }

    // MARK: - Controller access

    /// Returns the controller for an element, creating it (and registering for
    /// uiElementDestroyed) if it doesn't yet exist.
    @discardableResult
    func controller(
        element: ElementType,
        bufferedOutput: AsyncStream<Output.Job>.Continuation,
        directOutput: any OutputContext
    ) async throws -> Controller {
        try await getOrCreateNode(
            element: element,
            bufferedOutput: bufferedOutput,
            directOutput: directOutput
        ).controller
    }

    /// Returns the controller for the parent of `element`, if one exists in the hierarchy.
    func parentController(for element: ElementType) -> (any Controller)? {
        nodes[element]?.parent?.controller
    }

    private func getOrCreateNode(
        element: ElementType,
        bufferedOutput: AsyncStream<Output.Job>.Continuation,
        directOutput: any OutputContext
    ) async throws -> Node {
        if let existing = nodes[element] {
            logger.debug("Cached node for \(element.debugDescription)")
            return existing
        }
        // Coalesce: if creation is already in flight for this element, await that task.
        // This closes the reentrancy window between the guard above and `nodes[element] = node`
        // below — both calls share one observer.stream() call and therefore one iterating task.
        if let pending = pendingNodes[element] {
            logger.debug("Coalescing node creation for \(element.debugDescription)")
            return try await pending.value
        }
        logger.debug("Creating node for \(element.debugDescription)")
        // The Task body inherits this actor's isolation, so it runs on our executor.
        // Storing it in pendingNodes before any await means reentrant callers see it immediately.
        let creationTask = Task<Node, any Error> { [observer, controllerFactory] in
            let destroyTask: Task<Void, any Error>?
            do {
                destroyTask = try await self.observerDestroyTask(element: element)
            } catch let error as ControllerObserverError {
                if case .notificationUnsupported = error {
                    /* expected */
                } else {
                    self.logger.error("\(error.localizedDescription)")
                }
                destroyTask = nil
            } catch {
                self.logger.error("\(error.localizedDescription)")
                destroyTask = nil
            }
            let controller = try await controllerFactory(
                element,
                bufferedOutput,
                directOutput,
                observer
            )
            let node = Node(
                element: element,
                controller: controller
            )
            node.destroyTask = destroyTask
            return node
        }
        pendingNodes[element] = creationTask
        do {
            let node = try await creationTask.value
            pendingNodes.removeValue(forKey: element)
            nodes[element] = node
            return node
        } catch {
            pendingNodes.removeValue(forKey: element)
            throw error
        }
    }

    // MARK: - Element destruction

    private func uiElementDestroyed(
        element: ElementType,
        userInfo: [String:SystemElementValueContainer]?
    ) async {
        logger.debug("\(element.debugDescription)")
        guard let node = nodes[element] else { return }
        await removeSubtree(node)
    }

    private func removeSubtree(_ node: Node) async {
        for child in node.children.values {
            await removeSubtree(child)
        }
        node.destroyTask?.cancel()
        do {
            try await node.controller.stop()
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        nodes.removeValue(forKey: node.element)
        node.parent?.children.removeValue(forKey: node.element)
    }

    // MARK: - Observer task

    private func observerDestroyTask(element: ElementType) async throws -> Task<Void, any Error> {
        let stream = try await observer.stream(
            element: element,
            notification: .uiElementDestroyed
        )
        let handler = target(action: ControllerHierarchy<ObserverType>.uiElementDestroyed)
        return Task(priority: .userInitiated) {
            do {
                for try await notification in stream {
                    await handler(
                        notification.element,
                        notification.info
                    )
                }
            } catch {
                self.logger.error("uiElementDestroyed stream error element=\(element.debugDescription) error=\(error.localizedDescription)")
            }
        }
    }
}
