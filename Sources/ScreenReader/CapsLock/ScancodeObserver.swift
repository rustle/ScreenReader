//
//  ScancodeObserver.swift
//
//  Copyright © 2018-2026 Doug Russell. All rights reserved.
//

import Foundation
import IOKit.hid

@MainActor
public class ScancodeObserver: Sendable {
    private var hidManager: IOHIDManager?
    private func inputValue(scancode: Int) -> [String:Int] {
        return [
            kIOHIDElementUsageMinKey : scancode,
            kIOHIDElementUsageMaxKey : scancode,
        ]
    }
    private func deviceMatching(
        usagePage: Int,
        usage: Int
    ) -> [String:Int] {
        return [
            kIOHIDDeviceUsagePageKey : usagePage,
            kIOHIDDeviceUsageKey : usage,
        ]
    }
    public func enable() throws {
        guard hidManager == nil else {
            return
        }
        let hidManager = IOHIDManager.manager()
        hidManager.setInputValue(matching: inputValue(scancode: scancode))
        hidManager.setDevice(
            matchingCriteria: deviceMatching(
                usagePage: kHIDPage_GenericDesktop,
                usage: kHIDUsage_GD_Keyboard
            )
        )
        hidManager.registerInputValue(
            callback: scancodeObserverIOValueCallback,
            context: unsafeReference
        )
        hidManager.schedule(in: mode)
        do {
            try hidManager.open()
        } catch {
            hidManager.unschedule()
            throw error
        }
        self.hidManager = hidManager
    }
    public func disable() throws {
        guard let hidManager = hidManager else {
            return
        }
        hidManager.unschedule()
        try hidManager.close()
        self.hidManager = nil
    }
    fileprivate func yield(
        scancode: Int,
        value: Int
    ) {
        guard self.scancode == scancode else {
            return
        }
        if value > 0 {
            continuation.yield(.down)
        } else {
            continuation.yield(.up)
        }
    }
    public enum Value: Sendable {
        case up
        case down
    }
    private let scancode: Int
    private let mode: CFRunLoopMode
    private let unsafeReference: UnsafeMutablePointer<ScancodeObserver>
    public let stream: AsyncStream<Value>
    private let continuation: AsyncStream<Value>.Continuation
    public init(scancode: Int,
                mode: CFRunLoopMode = .defaultMode) {
        self.scancode = scancode
        self.mode = mode
        (stream, continuation) = AsyncStream<Value>.makeStream()
        unsafeReference = UnsafeMutablePointer<ScancodeObserver>.allocate(capacity: 1)
        unsafeReference.initialize(to: self)
    }
    isolated deinit {
        unsafeReference.deinitialize(count: 1)
        unsafeReference.deallocate()
    }
}

private func scancodeObserverIOValueCallback(
    _ context: UnsafeMutableRawPointer?,
    _ returnValue: IOReturn,
    _ sender: UnsafeMutableRawPointer?,
    _ value: IOHIDValue
) {
    guard let context else {
        return
    }
    let observer = context
        .assumingMemoryBound(to: ScancodeObserver.self)
        .pointee
    let element = value.element
    let scancode = element.usage
    let integerValue = value.integerValue
    MainActor.assumeIsolated {
        observer
            .yield(
                scancode: scancode,
                value: integerValue
            )
    }
}
