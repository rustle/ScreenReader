//
//  ArrayObserver.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Foundation

/// Type and value of a single change notification
public enum ArrayChange<Element>: Equatable where Element: Equatable {
    public static func ==(
        lhs: Self,
        rhs: Self
    ) -> Bool {
        switch lhs {
        case .set(let lValue):
            switch rhs {
            case .set(let rValue):
                return lValue == rValue
            case .insert(_):
                return false
            case .remove(_):
                return false
            case .replace(_, _):
                return false
            }
        case .insert(let lValue):
            switch rhs {
            case .set(_):
                return false
            case .insert(let rValue):
                return lValue == rValue
            case .remove(_):
                return false
            case .replace(_, _):
                return false
            }
        case .remove(let lValue):
            switch rhs {
            case .set(_):
                return false
            case .insert(_):
                return false
            case .remove(let rValue):
                return lValue == rValue
            case .replace(_, _):
                return false
            }
        case .replace(let lValue1, let lValue2):
            switch rhs {
            case .set(_):
                return false
            case .insert(_):
                return false
            case .remove(_):
                return false
            case .replace(let rValue1, let rValue2):
                return
                    lValue1 == rValue1 &&
                    lValue2 == rValue2
            }
        }
    }
    /// Indicates that the value of the observed key path was set to a new value. This change can occur when observing an attribute of an object, as well as properties that specify to-one and to-many relationships.
    case set([Element])
    /// Indicates that an object has been inserted into the to-many relationship that is being observed.
    case insert([Element])
    /// Indicates that an object has been removed from the to-many relationship that is being observed.
    case remove([Element])
    /// Indicates that an object has been replaced in the to-many relationship that is being observed.
    case replace([Element], [Element])
    public func map<ElementOfResult>(_ transform: (Element) -> ElementOfResult) -> ArrayChange<ElementOfResult> {
        switch self {
        case .set(let elements):
            .set(elements.map(transform))
        case .insert(let elements):
            .insert(elements.map(transform))
        case .remove(let elements):
            .remove(elements.map(transform))
        case let .replace(l, r):
            .replace(l.map(transform), r.map(transform))
        }
    }
}

extension ArrayChange: Sendable where Element: Sendable {}

/// Repackage KVO updates to an observable array
public final class ArrayObserver<Root, Element> where Root: NSObject, Element: Equatable {
    private let observer: NSKeyValueObservation
    init(
        root: Root,
        keypath: KeyPath<Root, [Element]>,
        changeHandler: @escaping @Sendable (ArrayChange<Element>) -> Void
    ) {
        observer = root.observe(
            keypath,
            options: [.initial, .new, .old]
        ) { root, change in
        switch change.kind {
        case .setting:
            guard let new = change.newValue else {
                return
            }
            changeHandler(.set(new))
        case .insertion:
            guard let new = change.newValue else {
                return
            }
            changeHandler(.insert(new))
        case .removal:
            guard let old = change.oldValue else {
                return
            }
            changeHandler(.remove(old))
        case .replacement:
            let old = change.oldValue ?? []
            let new = change.newValue ?? []
            changeHandler(.replace(old, new))
        @unknown default:
            break
        }
    }
}
}
