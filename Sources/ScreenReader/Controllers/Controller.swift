//
//  Controller.swift
//
//  Copyright © 2017-2023 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa

public protocol Controller: Actor {
    var identifier: AnyHashable { get async }
    func start() async throws
    func stop() async throws
    func focus() async throws
}

extension Controller {
    public func focus() async throws {}
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
        handler: @escaping @Sendable (ObserverType.ObserverElement, [String:Sendable]?) async -> Void
    ) async throws -> Task<Void, any Error> {
        do {
            let stream = try await observer.stream(
                element: element,
                notification: notification
            )
            return Task(priority: .userInitiated) {
                for try await notification in stream {
                    await handler(
                        notification.element,
                        notification.info
                    )
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
                throw ControllerObserverError.cannotComplete
            default:
                throw error
            }
        } catch {
            throw error
        }
    }
}
