//
//  CapsLock.swift
//
//  Copyright © 2018-2026 Doug Russell. All rights reserved.
//

import Foundation
import IOKit
import IOKit.hid
import os

@MainActor
public final class CapsLock: Sendable {
    public enum KeyState: Sendable {
        case up
        case down
    }
    public enum LockState: Sendable {
        case on
        case off
    }
    public var doubleTapToEnableCapsLock: Bool = true
    public var doubleTapToEnableCapsLockThreshold: Duration = .milliseconds(500)
    private var lastUp = ContinuousClock.now
    public let stream: AsyncStream<KeyState>
    private let streamContinuation: AsyncStream<KeyState>.Continuation
    public var lockState: LockState {
        get {
            if systemState.capsLocked {
                return .on
            } else {
                return .off
            }
        }
        set {
            switch newValue {
            case .on:
                systemState.capsLocked = true
            case .off:
                systemState.capsLocked = false
            }
        }
    }
    private let scancodeObserver = ScancodeObserver(
        scancode: kHIDUsage_KeyboardCapsLock
    )
    private let systemState: CapsLockSystemState
    private var scancodeStreamTask: Task<Void, any Error>?
    public init() throws {
        systemState = try CapsLockSystemState()
        (stream, streamContinuation) = AsyncStream<KeyState>.makeStream()
        let scancodeStream = scancodeObserver.stream.map { value in
            switch value {
            case .up:
                KeyState.up
            case .down:
                KeyState.down
            }
        }
        scancodeStreamTask = scancodeStream.target(
            self,
            priority: .userInitiated,
            action: CapsLock.yield(keyState:)
        )
        try scancodeObserver.enable()
    }
    private func yield(keyState: KeyState) {
        switch keyState {
        case .up:
            let now = ContinuousClock.now
            if doubleTapToEnableCapsLock {
                if now - lastUp < doubleTapToEnableCapsLockThreshold {
                    systemState.capsLocked = true
                } else {
                    systemState.capsLocked = false
                }
            } else {
                systemState.capsLocked = false
            }
            lastUp = now
            break
        case .down:
            break
        }
        streamContinuation.yield(keyState)
    }
    isolated deinit {
        scancodeStreamTask?.cancel()
        try? scancodeObserver.disable()
    }
}

private class CapsLockSystemState {
    public enum Error : Swift.Error {
        case ioError
    }
    public var capsLocked: Bool {
        get {
            var state = false
            IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state);
            return state
        }
        set {
            IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), newValue)
        }
    }
    public func toggle() {
        capsLocked = !capsLocked
    }
    private var connect: io_connect_t = 0
    public init() throws {
        let matching = IOServiceMatching(kIOHIDSystemClass)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        if service == 0 {
            throw CapsLockSystemState.Error.ioError
        }
        let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
        IOObjectRelease(service)
        guard result == KERN_SUCCESS else {
            throw CapsLockSystemState.Error.ioError
        }
    }
    deinit {
        IOServiceClose(connect)
    }
}
