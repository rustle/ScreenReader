//
//  IOHIDDevice.swift
//
//  Copyright © 2018-2026 Doug Russell. All rights reserved.
//

import Foundation
import IOKit

extension IOHIDDevice {
    static var typeID: CFTypeID {
        return IOHIDDeviceGetTypeID()
    }
}
