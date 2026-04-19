//
//  IOHIDElement.swift
//
//  Copyright © 2018-2026 Doug Russell. All rights reserved.
//

import Foundation
import IOKit

extension IOHIDElement {
    static var typeID: CFTypeID {
        return IOHIDElementGetTypeID()
    }
    var usage: Int {
        return Int(IOHIDElementGetUsage(self))
    }
    var usagePage: Int {
        return Int(IOHIDElementGetUsagePage(self))
    }
}
