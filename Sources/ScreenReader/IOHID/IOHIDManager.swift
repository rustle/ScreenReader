//
//  IOHIDManager.swift
//
//  Copyright © 2018-2026 Doug Russell. All rights reserved.
//

import Foundation
import IOKit

extension IOHIDManager {
    static func manager(options: IOOptionBits = IOOptionBits()) -> IOHIDManager {
        return IOHIDManagerCreate(kCFAllocatorDefault,
                                  options)
    }
    func setInputValue(matching: [String:Int]) {
        let reduced = matching.reduce(into: [NSString:NSNumber]()) { result, pair in
            result[pair.key as NSString] = NSNumber(value: pair.value)
        }
        IOHIDManagerSetInputValueMatching(self,
                                          reduced as CFDictionary)
    }
    func setDevice(matchingCriteria: [String:Int]) {
        let reduced = matchingCriteria.reduce(into: [NSString:NSNumber]()) { result, pair in
            result[pair.key as NSString] = NSNumber(value: pair.value)
        }
        IOHIDManagerSetDeviceMatching(self,
                                      reduced as CFDictionary)
    }
    func setDevice(matchingCriterias: [[String:Int]]) {
        let mapped: [[NSString:NSNumber]] = matchingCriterias.map { criteria in
            let reduced = criteria.reduce(into: [NSString:NSNumber]()) { result, pair in
                result[pair.key as NSString] = NSNumber(value: pair.value)
            }
            return reduced
        }
        IOHIDManagerSetDeviceMatchingMultiple(self,
                                              mapped as CFArray)
    }
    func registerInputValue(callback: IOHIDValueCallback?,
                            context: UnsafeMutableRawPointer?) {
        IOHIDManagerRegisterInputValueCallback(self,
                                               callback,
                                               context)
    }
    func schedule(on runloop: CFRunLoop = CFRunLoopGetMain(),
                  in mode: CFRunLoopMode = .defaultMode) {
        IOHIDManagerScheduleWithRunLoop(self,
                                        runloop,
                                        mode.rawValue)
    }
    func unschedule(on runloop: CFRunLoop = CFRunLoopGetMain(),
                    in mode: CFRunLoopMode = .defaultMode) {
        IOHIDManagerUnscheduleFromRunLoop(self,
                                          runloop,
                                          mode.rawValue)
    }
    enum IOReturnError : Error {
        case unsuccessful(IOReturn)
    }
    func open(options: IOOptionBits = IOOptionBits()) throws {
        let result = IOHIDManagerOpen(self,
                                      options)
        guard result == kIOReturnSuccess else {
            throw IOReturnError.unsuccessful(result)
        }
    }
    func close(options: IOOptionBits = IOOptionBits()) throws {
        let result = IOHIDManagerClose(self,
                                       options)
        guard result == kIOReturnSuccess else {
            throw IOReturnError.unsuccessful(result)
        }
    }
    var devices: Set<IOHIDDevice> {
        guard let d = IOHIDManagerCopyDevices(self) else {
            return Set()
        }
        guard let devices = d as? Set<IOHIDDevice> else {
            return Set()
        }
        return devices
    }
}

