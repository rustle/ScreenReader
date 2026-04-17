//
//  TextArea.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import TargetAction
import os

public actor TextArea<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
    public var identifier: AnyHashable {
        element
    }

    public nonisolated let unownedExecutor: UnownedSerialExecutor
    let observer: ApplicationObserver<ObserverType>

    private var observerTasks: [Task<Void, any Error>] = []
    private var runState: RunState = .stopped
    private let output: AsyncStream<Output.Job>.Continuation
    /// The controller for this element's parent in the controller hierarchy.
    weak private var parentController: (any Controller)?
    private var logger: Logger {
        Loggers.Controller.textArea
    }

    private var previousCharacterCount: Int = 0
    private var previousSelectedRange: Range<Int> = 0..<0
    private var previousLineNumber: Int = 0
    private var valueDidChangeThisCycle: Bool = false

    private var textBuffer: String = ""
    private var bufferRange: Range<Int> = 0..<0
    private let bufferRadius: Int = 128

    public init(
        element: ElementType,
        output: AsyncStream<Output.Job>.Continuation,
        observer: ApplicationObserver<ObserverType>,
        executor: RunLoopExecutor
    ) async throws {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
        self.element = element
        self.output = output
        self.observer = observer
    }

    public func setParent(_ controller: (any Controller)?) async {
        parentController = controller
    }

    public func start() async throws {
        guard runState == .stopped else { return }
        do {
            observerTasks.append(try await add(
                notification: .valueChanged,
                handler: target(action: TextArea<ObserverType>.valueChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        do {
            observerTasks.append(try await add(
                notification: .selectedTextChanged,
                handler: target(action: TextArea<ObserverType>.selectedTextChanged)
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        runState = .running
    }
    public func output(event: ControllerOutputEvent) async throws -> [Output.Job.Payload] {
        var parts = [String]()
        if let title = try? element.title(), !title.isEmpty {
            parts.append(title)
        } else if let titleUIElement = try? element.titleUIElement(), let title = try? titleUIElement.title(), !title.isEmpty {
            parts.append(title)
        }
        if let roleDescription = try? element.roleDescription() {
            parts.append(roleDescription)
        }
        guard !parts.isEmpty else { return [] }
        return [.speech(parts.joined(separator: ", "), nil)]
    }
    public func focus() async throws {
        previousCharacterCount = (try? element.numberOfCharacters()) ?? 0
        previousSelectedRange = (try? element.selectedTextRange()) ?? 0..<0
        previousLineNumber = (try? element.line(forIndex: previousSelectedRange.lowerBound)) ?? 0
        try? refreshBuffer(caret: previousSelectedRange.lowerBound)
        let payloads = try await output(event: .focusIn)
        guard !payloads.isEmpty else { return }
        output.yield(.init(
            options: [],
            identifier: "",
            payloads: payloads
        ))
    }

    public func stop() async throws {
        guard runState == .running else { return }
        observerTasks = []
        runState = .stopped
    }
    private func refreshBuffer(caret: Int) throws {
        let start = max(0, caret - bufferRadius)
        let end = min(previousCharacterCount, caret + bufferRadius)
        guard start < end else {
            textBuffer = ""
            bufferRange = start..<start
            return
        }
        textBuffer = try element.string(for: start..<end)
        bufferRange = start..<end
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:ObserverElementInfoValue]?
    ) async {
        defer { valueDidChangeThisCycle = true }
        guard let newCount = try? element.numberOfCharacters(),
              let newRange = try? element.selectedTextRange() else { return }
        let delta = newCount - previousCharacterCount
        let text: String?
        if delta > 0 {
            let insertedRange = max(0, newRange.lowerBound - delta)..<newRange.lowerBound
            text = try? element.string(for: insertedRange)
        } else if delta < 0 {
            let deletedCount = abs(delta)
            let deletedStart = newRange.lowerBound
            let deletedEnd = deletedStart + deletedCount
            let highConfidence = bufferRange.lowerBound <= deletedStart && deletedEnd <= bufferRange.upperBound
            if highConfidence {
                let bufferOffset = deletedStart - bufferRange.lowerBound
                let startIndex = textBuffer.index(textBuffer.startIndex, offsetBy: bufferOffset)
                let endIndex = textBuffer.index(startIndex, offsetBy: deletedCount)
                text = String(textBuffer[startIndex..<endIndex])
            } else {
                // TODO: Use a sound instead of "deleted"
                text = "deleted"
            }
        } else {
            text = nil
        }
        previousCharacterCount = newCount
        previousSelectedRange = newRange
        previousLineNumber = (try? element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
        try? refreshBuffer(caret: newRange.lowerBound)
        guard let text, !text.isEmpty else { return }
        output.yield(.init(
            options: [],
            identifier: "",
            payloads: [.speech(text, nil)]
        ))
    }

    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:ObserverElementInfoValue]?
    ) async {
        guard !valueDidChangeThisCycle else {
            valueDidChangeThisCycle = false
            return
        }
        guard let newRange = try? element.selectedTextRange() else { return }
        defer {
            previousSelectedRange = newRange
            previousLineNumber = (try? element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
            try? refreshBuffer(caret: newRange.lowerBound)
        }
        if !newRange.isEmpty {
            guard let selected = try? element.selectedText(), !selected.isEmpty else { return }
            output.yield(.init(
                options: [],
                identifier: "",
                // TODO: Localization
                payloads: [.speech("\(selected) selected", nil)]
            ))
        } else if newRange.lowerBound != previousSelectedRange.lowerBound {
            let delta = abs(newRange.lowerBound - previousSelectedRange.lowerBound)
            let newLine = (try? element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
            if delta > 1 && newLine != previousLineNumber {
                // ↑/↓ navigation: speak the full new line
                guard let lineRange = try? element.range(forLine: newLine),
                      let lineText = try? element.string(for: lineRange) else { return }
                // TODO: Use a sound instead of "blank"
                let spoken = lineText.trimmingCharacters(in: .newlines).isEmpty ? "blank" : lineText
                output.yield(.init(
                    options: [],
                    identifier: "",
                    payloads: [.speech(spoken, .interrupt)]
                ))
            } else {
                // Character or word navigation, including Right/Left crossing a line boundary
                let lo = min(previousSelectedRange.lowerBound, newRange.lowerBound)
                let hi = max(previousSelectedRange.lowerBound, newRange.lowerBound)
                guard let jumped = try? element.string(for: lo..<hi), !jumped.isEmpty else { return }
                let speechOptions: Output.Options = delta == 1 ? [.byCharacter, .interrupt] : .interrupt
                output.yield(.init(
                    options: [],
                    identifier: "",
                    payloads: [.speech(jumped, speechOptions)]
                ))
            }
        }
    }
}

extension TextArea: ObserverHosting {}
