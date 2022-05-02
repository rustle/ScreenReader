//
//  Application.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AX
import AccessibilityElement
import Cocoa
import os

public actor Application: Controller {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "Application")
    private let element: SystemElement
    private var observer: ApplicationObserver!
    private var observerTokens: [ApplicationObserver.ObserverToken] = []
    private var windows: [SystemElement:Window] = [:]
    private var focusedUIElement: Controller?
    public convenience init(processIdentifier: pid_t) async throws {
        try await self.init(element: try SystemElement.application(processIdentifier: processIdentifier))
    }
    public init(element: SystemElement) async throws {
        self.element = element
    }
    public func start() async throws {
        observer = .init(observer: try await SystemObserver(pid: try element.processIdentifier))
        try await observer.start()
        observerTokens.append(try await observer.add(element: element,
                                                     notification: .windowCreated,
                                                     handler: isolated(action: Application.windowCreated)))
        observerTokens.append(try await observer.add(element: element,
                                                     notification: .focusedWindowChanged,
                                                     handler: isolated(action: Application.focusedWindowChanged)))
        observerTokens.append(try await observer.add(element: element,
                                                     notification: .focusedUIElementChanged,
                                                     handler: isolated(action: Application.focusedUIElementChanged)))
        for window in try element.windows() {
            try await add(window: window)
        }
    }
    public func stop() async throws {
        observer = nil
    }
    private func windowCreated(
        window: SystemElement,
        userInfo: [String:Any]?
    ) async {
        Self.logger.info("\(#function) \(window)")
        do {
            try await self.add(window: window)
        } catch {}
    }
    private func windowDestroyed(
        window: SystemElement,
        userInfo: [String:Any]?
    ) async {
        Self.logger.info("\(#function) \(window)")
    }
    private func focusedWindowChanged(
        window: SystemElement,
        userInfo: [String:Any]?
    ) async {
        Self.logger.info("\(#function) \(window)")
    }
    private func focusedUIElementChanged(
        element: SystemElement,
        userInfo: [String:Any]?
    ) async {
        Self.logger.info("\(#function) \(element.debugDescription)")
        do {
            try await focusedUIElement?.stop()
        } catch {
            Self.logger.error("\(error.localizedDescription)")
        }
        do {
            focusedUIElement = try await Self.controller(
                element: element,
                observer: observer
            )
        } catch {
            Self.logger.error("\(error.localizedDescription)")
        }
        do {
            try await focusedUIElement?.start()
            try await focusedUIElement?.focus()
        } catch {
            Self.logger.error("\(error.localizedDescription)")
        }
    }
    private func add(window: SystemElement) async throws {
        do {
            observerTokens.append(try await observer.add(element: element,
                                                         notification: .uiElementDestroyed,
                                                         handler: isolated(action: Application.windowDestroyed)))
        } catch {
            Self.logger.error("\(error.localizedDescription)")
        }
        let windowController = try await Window(
            element: window,
            observer: observer
        )
        windows[window] = windowController
        try await windowController.start()
    }
}

extension Application {
    public static func controller(
        element: SystemElement,
        observer: ApplicationObserver
    ) async throws -> Controller {
        let role = try element.role()
        switch role {
        case .button:
            return try await Button(
                element: element,
                observer: observer
            )
        case .comboBox:
            return try await ComboBox(
                element: element,
                observer: observer
            )
        case .list:
            return try await List(
                element: element,
                observer: observer
            )
        case .table:
            return try await Table(
                element: element,
                observer: observer
            )
        case .window:
            return try await Window(
                element: element,
                observer: observer
            )
        default:
            return try await Unknown(
                element: element,
                observer: observer
            )
        }
    }
}
