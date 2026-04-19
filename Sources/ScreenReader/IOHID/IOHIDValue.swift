//
//  IOHIDValue.swift
//
//  Copyright © 2018-2026 Doug Russell. All rights reserved.
//

import Foundation
import IOKit

extension IOHIDValue {
    var element: IOHIDElement {
        return IOHIDValueGetElement(self)
    }
    var integerValue: Int {
        return IOHIDValueGetIntegerValue(self)
    }
}
