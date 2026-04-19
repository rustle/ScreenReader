//
//  CommandSource.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

/// A command source maps raw input (keyboard, switch access, etc.) to
/// `ScreenReaderCommand` values and deliver them via `dispatch`.
/// Use `ScreenReader.addCommandSource(_:)` / `removeCommandSource(_:)` to
/// register and deregister sources at any point during the app's lifetime.
public protocol CommandSource: AnyObject, Sendable {
    /// Caller-provided identifier. Must be unique across all registered sources.
    nonisolated var identifier: String { get }
    nonisolated var dispatch: AsyncStream<ScreenReaderCommand> { get }
}
