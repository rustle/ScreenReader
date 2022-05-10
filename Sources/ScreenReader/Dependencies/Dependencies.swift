//
//  Dependencies.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Foundation

public struct Dependencies {
    public let screenReaderDependenciesFactory: () -> ScreenReaderDependencies
    public let serverProviderDependenciesFactory: () -> ServerProviderDependencies
    public init(
        screenReaderDependenciesFactory: @escaping () -> ScreenReaderDependencies,
        serverProviderDependenciesFactory: @escaping () -> ServerProviderDependencies
    ) {
        self.screenReaderDependenciesFactory = screenReaderDependenciesFactory
        self.serverProviderDependenciesFactory = serverProviderDependenciesFactory
    }
}
