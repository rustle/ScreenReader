//
//  Actor.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

extension Actor {
    /// Helper function to make a closure from a method on an actor instance without retaining self
    func isolated<Input>(action: @escaping (isolated Self) -> (Input) async -> Void) -> (Input) async -> Void {
        return { [weak self] input in
            guard let self = self else { return }
            return await action(self)(input)
        }
    }
    /// Helper function to make a closure from a method on an actor instance without retaining self
    func isolated<Input1, Input2>(action: @escaping (isolated Self) -> (Input1, Input2) async -> Void) -> (Input1, Input2) async -> Void {
        return { [weak self] input1, input2 in
            guard let self = self else { return }
            return await action(self)(input1, input2)
        }
    }
}
