//
//  File.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Foundation
@preconcurrency import os

public struct ServerProviderDependencies: Sendable {
    public let logger = Logger(
        subsystem: "ScreenReader",
        category: "ServerProvider"
    )
    public let inclusionListFactory: @Sendable () -> Set<BundleIdentifier>
    public let exclusionListFactory: @Sendable () -> Set<BundleIdentifier>
    public init(
        inclusionListFactory: @escaping @Sendable () -> Set<BundleIdentifier>,
        exclusionListFactory: @escaping @Sendable () -> Set<BundleIdentifier>
    ) {
        self.inclusionListFactory = inclusionListFactory
        self.exclusionListFactory = exclusionListFactory
    }
}
