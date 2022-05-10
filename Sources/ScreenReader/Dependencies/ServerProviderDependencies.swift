//
//  File.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Foundation
import os

public struct ServerProviderDependencies {
    public let logger = Logger(
        subsystem: "ScreenReader",
        category: "ServerProvider"
    )
    public let inclusionListFactory: () -> Set<BundleIdentifier>
    public let exclusionListFactory: () -> Set<BundleIdentifier>
    public init(
        inclusionListFactory: @escaping () -> Set<BundleIdentifier>,
        exclusionListFactory: @escaping () -> Set<BundleIdentifier>
    ) {
        self.inclusionListFactory = inclusionListFactory
        self.exclusionListFactory = exclusionListFactory
    }
}
