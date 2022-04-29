//
//  ScreenReader.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AX
import Cocoa
import os

public final class ScreenReader {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "ScreenReader")
    public init() {}
    public func confirmTrust() {
        guard isTrusted(promptIfNeeded: true) else {
            // If you already added ScreenReader
            // to trusted apps, it's likely that changing the
            // binary has invalidated it's AX API access.
            // You can usually reauthorize it by unchecking and
            // rechecking it's entry in the list of apps
            // with AX API access in System Preferences.
            Self.logger.error("Not Trusted")
            exit(1)
        }
    }
}
