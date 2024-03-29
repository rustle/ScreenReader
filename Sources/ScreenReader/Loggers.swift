//
//  Loggers.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import os

struct Loggers {
    static let logger = Logger(
        subsystem: "ScreenReader",
        category: "ScreenReader"
    )
    static let server = Logger(
        subsystem: "ScreenReader",
        category: "Server"
    )
    static let hierarchy = Logger(
        subsystem: "ScreenReader",
        category: "Hierarchy"
    )
    struct Controller {
        static let application = Logger(
            subsystem: "ScreenReader",
            category: "Application"
        )
        static let button = Logger(
            subsystem: "ScreenReader",
            category: "Button"
        )
        static let comboBox = Logger(
            subsystem: "ScreenReader",
            category: "ComboBox"
        )
        static let group = Logger(
            subsystem: "ScreenReader",
            category: "Group"
        )
        static let list = Logger(
            subsystem: "ScreenReader",
            category: "List"
        )
        static let table = Logger(
            subsystem: "ScreenReader",
            category: "Table"
        )
        static let textField = Logger(
            subsystem: "ScreenReader",
            category: "TextField"
        )
        static let textArea = Logger(
            subsystem: "ScreenReader",
            category: "TextArea"
        )
        static let unknown = Logger(
            subsystem: "ScreenReader",
            category: "Unknown"
        )
        static let webArea = Logger(
            subsystem: "ScreenReader",
            category: "WebArea"
        )
        static let window = Logger(
            subsystem: "ScreenReader",
            category: "Window"
        )
    }
    struct Output {
        static let output = Logger(
            subsystem: "ScreenReader",
            category: "Output"
        )
        static let braille = Logger(
            subsystem: "ScreenReader",
            category: "Braille"
        )
        static let speech = Logger(
            subsystem: "ScreenReader",
            category: "Speech"
        )
        static let text = Logger(
            subsystem: "ScreenReader",
            category: "Text"
        )
    }
}
