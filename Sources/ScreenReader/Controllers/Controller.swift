//
//  Controller.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa
import os

public enum ControllerOutputEvent: Sendable {
    case focusThrough
    case focusIn
    case focusOut
}

public protocol Controller: Actor {
    var identifier: AnyHashable { get async }
    func start() async throws
    func stop() async throws
    /// Called when this controller becomes the focused leaf of the focus chain.
    func focus() async throws
    /// Called when this controller leaves the focus chain (but its element still exists).
    func unfocus() async throws
    /// Returns Output payloads that describe this element as context for a child gaining focus.
    /// Used for intermediate nodes in the focus chain (window titles, group labels, etc.).
    func output(event: ControllerOutputEvent) async throws -> [Output.Job.Payload]
    /// Called by ControllerHierarchy when this controller's parent in the hierarchy changes.
    func setParent(_ controller: (any Controller)?) async
}

extension Controller {
    public func focus() async throws {}
    public func unfocus() async throws {}
    public func output(event: ControllerOutputEvent) async throws -> [Output.Job.Payload] { [] }
    public func setParent(_ controller: (any Controller)?) async {}
}

enum ControllerObserverError: Error {
    case notImplemented
    case notificationUnsupported
    case invalidUIElement
    case cannotComplete
    case multiple([Error])
    public var localizedDescription: String {
        switch self {
        case .notImplemented:
            return "ControllerObserverError.notImplemented - Indicates that the function or method is not implemented (this can be returned if a process does not support the accessibility API)."
        case .notificationUnsupported:
            return "ControllerObserverError.notificationUnsupported - The notification is not supported by the UIElement"
        case .invalidUIElement:
            return "ControllerObserverError.invalidUIElement - The UIElement passed to the function is invalid."
        case .cannotComplete:
            return "ControllerObserverError.cannotComplete - The function cannot complete because messaging failed in some way or because the application with which the function is communicating is busy or unresponsive."
        case .multiple(let errors):
            let descriptions = errors.map {
                $0.localizedDescription
            }
            return "ControllerObserverError.multiple - (\n\(descriptions.joined(separator: ",\n"))\n)"
        }
    }
}

enum RunState {
    case running
    case stopped
}

extension Controller {
    @Sendable
    static func add<ObserverType: Observer>(
        observer: ApplicationObserver<ObserverType>,
        element: ObserverType.ObserverElement,
        notification: NSAccessibility.Notification,
        handler: @escaping @Sendable (ObserverType.ObserverElement, [String:ObserverElementInfoValue]?) async -> Void
    ) async throws -> Task<Void, any Error> {
        do {
            let stream = try await observer.stream(
                element: element,
                notification: notification
            )
            return Task(priority: .userInitiated) {
                do {
                    for try await notification in stream {
                        await handler(
                            notification.element,
                            notification.info
                        )
                    }
                } catch {
                    Loggers.Controller.observer.error("stream error element=\(element.description) notification=\(notification.rawValue) error=\(error.localizedDescription)")
                }
            }
        } catch let error as ObserverError {
            switch error {
            case .notImplemented:
                throw ControllerObserverError.notImplemented
            case .notificationUnsupported:
                throw ControllerObserverError.notificationUnsupported
            case .invalidUIElement:
                throw ControllerObserverError.invalidUIElement
            case .cannotComplete:
#if DEBUG
                if let sysElement = element as? SystemElement {
                    Loggers.Controller.observer.error("cannotComplete element=\(sysElement.debugInfo) notification=\(notification.rawValue)")
                } else {
                    Loggers.Controller.observer.error("cannotComplete element=\(element.description) notification=\(notification.rawValue)")
                }
#else
                Loggers.Controller.observer.error("cannotComplete element=\(element.description) notification=\(notification.rawValue)")
#endif
                throw ControllerObserverError.cannotComplete
            default:
                throw error
            }
        } catch {
            throw error
        }
    }
}
