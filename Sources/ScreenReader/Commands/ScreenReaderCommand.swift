//
//  ScreenReaderCommand.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Cocoa

public enum ScreenReaderCommand: Sendable, Hashable {
    // Spatial navigation within the focused element (arrow-key style)
    case moveUp
    case moveDown
    case moveLeft
    case moveRight

    // Accessibility tree navigation
    case navigateIn         // descend into the focused element's children
    case navigateOut        // ascend to the parent element
    case navigateNext       // move to the next sibling
    case navigatePrevious   // move to the previous sibling

    // Reading
    case readAll
    case stopReading

    // Actions
    case performDefaultAction
    case performAction(NSAccessibility.Action)
}
