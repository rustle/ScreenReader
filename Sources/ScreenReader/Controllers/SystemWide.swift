//
//  SystemWide.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Cocoa
import os

public actor SystemWide: Controller {
    private let element: SystemElement
    private let focusedRunningApplication: any FocusedRunningApplication
    private var lastFocusedPID: pid_t = 0
    private var observationTask: Task<Void, Never>?
    private var logger: Logger {
        Loggers.Controller.systemWide
    }

    public var identifier: AnyHashable {
        element
    }

    /// Yields the pid of the frontmost application each time it changes.
    /// Only emits when the pid differs from the last observed value.
    public nonisolated let focusedApplicationStream: AsyncStream<pid_t>
    private let focusedApplicationContinuation: AsyncStream<pid_t>.Continuation

    public init(focusedRunningApplication: any FocusedRunningApplication) throws {
        let element = try SystemElement.systemWide()
        self.element = element
        self.focusedRunningApplication = focusedRunningApplication
        (focusedApplicationStream, focusedApplicationContinuation) = AsyncStream<pid_t>.makeStream()
    }

    public func start() async throws {
        observationTask = Task { [self] in
            for await workspacePID in focusedRunningApplication.stream {
                handleFocusChange(workspacePID: workspacePID)
            }
        }
    }

    public func stop() async throws {
        observationTask?.cancel()
        observationTask = nil
        focusedApplicationContinuation.finish()
    }

    /// Polls the system-wide AX element for the focused UI element's owning PID.
    /// Falls back to the workspace PID if AX polling fails (e.g. no focused element).
    private func handleFocusChange(workspacePID: pid_t) {
        let pid: pid_t
        do {
            let focusedUIElement = try element.focusedUIElement()
            pid = try focusedUIElement.processIdentifier
            logger.debug("AX focused pid=\(pid) workspacePID=\(workspacePID)")
        } catch {
            logger.debug("AX poll failed (\(error.localizedDescription)), using workspace pid=\(workspacePID)")
            pid = workspacePID
        }
        guard lastFocusedPID != pid else { return }
        logger.debug("Focused application changed: \(pid)")
        lastFocusedPID = pid
        focusedApplicationContinuation.yield(pid)
    }
}
