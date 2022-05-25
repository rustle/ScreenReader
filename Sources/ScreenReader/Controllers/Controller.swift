//
//  Controller.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa

public protocol Controller: Actor {
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
}

extension Controller {
    static func add<ObserverType: Observer>(
        observer: ApplicationObserver<ObserverType>,
        element: ObserverType.ObserverElement,
        notification: NSAccessibility.Notification,
        handler: @escaping (ObserverType.ObserverElement, [String:Any]?) async -> Void
    ) async throws -> ApplicationObserver<ObserverType>.ApplicationObserverToken {
        do {
            return try await observer.add(
                element: element,
                notification: notification,
                handler: handler
            )
        } catch let error as ObserverError {
            switch error {
            case .notImplemented:
                throw ControllerObserverError.notImplemented
            case .notificationUnsupported:
                throw ControllerObserverError.notificationUnsupported
            case .invalidUIElement:
                throw ControllerObserverError.invalidUIElement
            default:
                throw error
            }
        } catch {
            throw error
        }
    }
}
