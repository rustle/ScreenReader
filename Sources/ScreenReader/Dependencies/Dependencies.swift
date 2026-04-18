//
//  Dependencies.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Foundation

public struct Dependencies: Sendable {
    public let screenReaderDependenciesFactory: @Sendable () -> ScreenReaderDependencies
    public let serverProviderDependenciesFactory: @Sendable () -> ServerProviderDependencies
    public init(
        screenReaderDependenciesFactory: @escaping @Sendable () -> ScreenReaderDependencies,
        serverProviderDependenciesFactory: @escaping @Sendable () -> ServerProviderDependencies
    ) {
        self.screenReaderDependenciesFactory = screenReaderDependenciesFactory
        self.serverProviderDependenciesFactory = serverProviderDependenciesFactory
    }
}
