//
//  List.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor List: Controller {
    static let logger = Logger(subsystem: "ScreenReader",
                               category: "List")
    private let element: SystemElement
    public init(element: SystemElement) async throws {
        self.element = element
    }
    public func start() async throws {
        
    }
    public func stop() async throws {
        
    }
}
