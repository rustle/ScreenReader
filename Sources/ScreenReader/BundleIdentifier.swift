//
//  BundleIdentifier.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

public struct BundleIdentifier: Sendable, RawRepresentable, CustomStringConvertible {
    public typealias RawValue = String
    public let rawValue: String
    public var description: String {
        rawValue
    }
    public init?(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }
    public init?(rawValue: String?) {
        guard let rawValue = rawValue else {
            return nil
        }
        self.rawValue = rawValue.lowercased()
    }
    public init(_ bundleIdentifier: String) {
        self.rawValue = bundleIdentifier.lowercased()
    }
}

extension BundleIdentifier: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)!
    }
}

extension BundleIdentifier: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
    public static func ==(lhs: BundleIdentifier,
                          rhs: BundleIdentifier) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
    public static func ==(lhs: BundleIdentifier,
                          rhs: String) -> Bool {
        lhs.rawValue.compare(rhs,
                             options: .caseInsensitive) == .orderedSame
    }
    public static func ==(lhs: String,
                          rhs: BundleIdentifier) -> Bool {
        lhs.compare(rhs.rawValue,
                    options: .caseInsensitive) == .orderedSame
    }
}
