//
//  Loggers.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import os

struct Loggers {
    static let button = Logger(
        subsystem: "ScreenReader",
        category: "Button"
    )
    static let comboBox = Logger(
        subsystem: "ScreenReader",
        category: "ComboBox"
    )
    static let list = Logger(
        subsystem: "ScreenReader",
        category: "List"
    )
    static let table = Logger(
        subsystem: "ScreenReader",
        category: "Table"
    )
    static let unknown = Logger(
        subsystem: "ScreenReader",
        category: "Unknown"
    )
    static let window = Logger(
        subsystem: "ScreenReader",
        category: "Window"
    )
}
