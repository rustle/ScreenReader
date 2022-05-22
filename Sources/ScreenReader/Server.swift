//
//  Server.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation

public enum ServerError: Error {
    case application(ApplicationError)
}

public actor Server {
    public let processIdentifier: pid_t
    public let bundleIdentifier: BundleIdentifier
    private let application: Controller
    public init(
        processIdentifier: pid_t,
        bundleIdentifier: BundleIdentifier,
        application: Controller
    ) async throws {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.application = application
    }
    public func start() async throws {
        do {
            try await application.start()
        } catch let error as ApplicationError {
            throw ServerError.application(error)
        } catch {
            throw error
        }
    }
    public func stop() async throws {
        do {
            try await application.stop()
        } catch let error as ApplicationError {
            throw ServerError.application(error)
        } catch {
            throw error
        }
    }
}

extension Server {
    public convenience init(
        processIdentifier: pid_t,
        bundleIdentifier: BundleIdentifier
    ) async throws {
        try await self.init(
            processIdentifier: processIdentifier,
            bundleIdentifier: bundleIdentifier,
            application: try await Application(processIdentifier: processIdentifier)
        )
    }
}
