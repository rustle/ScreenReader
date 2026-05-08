//
//  TextArea.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import RunLoopExecutor
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
    private var readAllTask: Task<Void, Never>?
    private let output: AsyncStream<Output.Job>.Continuation
    /// Direct output context for operations that need backpressure (e.g. read-all),
    /// bypassing the Application's bufferingNewest(1) stream.
    private let directOutput: any OutputContext
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
    
    public struct TextAreaOutput {
        let directOutput: any OutputContext
        let bufferedOutput: AsyncStream<Output.Job>.Continuation
    }

    public init(
        element: ElementType,
        output: TextAreaOutput,
        observer: ApplicationObserver<ObserverType>,
        executor: RunLoopExecutor
    ) async throws {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
        self.element = element
        self.output = output.bufferedOutput
        self.observer = observer
        self.directOutput = output.directOutput
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
        if let title = try? await element.title(), !title.isEmpty {
            parts.append(title)
        } else if let titleUIElement = try? await element.titleUIElement(), let title = try? await titleUIElement.title(), !title.isEmpty {
            parts.append(title)
        }
        if let roleDescription = try? await element.roleDescription() {
            parts.append(roleDescription)
        }
        guard !parts.isEmpty else { return [] }
        return [.speech(parts.joined(separator: ", "), nil)]
    }
    public func focus() async throws {
        previousCharacterCount = (try? await element.numberOfCharacters()) ?? 0
        previousSelectedRange = (try? await element.selectedTextRange()) ?? 0..<0
        previousLineNumber = (try? await element.line(forIndex: previousSelectedRange.lowerBound)) ?? 0
        try? await refreshBuffer(caret: previousSelectedRange.lowerBound)
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
    private func refreshBuffer(caret: Int) async throws {
        guard caret >= 0, caret <= previousCharacterCount else {
            textBuffer = ""
            bufferRange = 0..<0
            return
        }
        let start = max(0, caret - bufferRadius)
        let end = min(previousCharacterCount, caret + bufferRadius)
        guard start < end else {
            textBuffer = ""
            bufferRange = start..<start
            return
        }
        textBuffer = try await element.string(for: start..<end)
        bufferRange = start..<end
    }
    private func valueChanged(
        element: ElementType,
        userInfo: [String:SystemElementValueContainer]?
    ) async {
        defer { valueDidChangeThisCycle = true }
        guard let newCount = try? await element.numberOfCharacters(),
              let newRange = try? await element.selectedTextRange() else { return }
        let delta = newCount - previousCharacterCount
        let text: String?
        if delta > 0 {
            let insertedRange = max(0, newRange.lowerBound - delta)..<newRange.lowerBound
            text = try? await element.string(for: insertedRange)
        } else if delta < 0 {
            let deletedCount = abs(delta)
            let deletedStart = newRange.lowerBound
            let deletedEnd = deletedStart + deletedCount
            let highConfidence = bufferRange.lowerBound <= deletedStart && deletedEnd <= bufferRange.upperBound
            if highConfidence {
                // AX reports positions as NSString (UTF-16) code-unit offsets, so
                // advance through the UTF-16 view to avoid miscounting multi-unit
                // scalars such as emoji (e.g. 👋 = 2 UTF-16 units, 1 grapheme cluster).
                let utf16 = textBuffer.utf16
                let startOffset = deletedStart - bufferRange.lowerBound
                let endOffset = startOffset + deletedCount
                if let utf16Start = utf16.index(utf16.startIndex, offsetBy: startOffset, limitedBy: utf16.endIndex),
                   let utf16End = utf16.index(utf16.startIndex, offsetBy: endOffset, limitedBy: utf16.endIndex),
                   let startIndex = utf16Start.samePosition(in: textBuffer),
                   let endIndex = utf16End.samePosition(in: textBuffer) {
                    text = String(textBuffer[startIndex..<endIndex])
                } else {
                    // TODO: Use a sound instead of "deleted"
                    text = "deleted"
                }
            } else {
                // TODO: Use a sound instead of "deleted"
                text = "deleted"
            }
        } else {
            text = nil
        }
        previousCharacterCount = newCount
        previousSelectedRange = newRange
        previousLineNumber = (try? await element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
        try? await refreshBuffer(caret: newRange.lowerBound)
        guard let text, !text.isEmpty else { return }
        output.yield(.init(
            options: [],
            identifier: "",
            payloads: [.speech(text, nil)]
        ))
    }

    private func selectedTextChanged(
        element: ElementType,
        userInfo: [String:SystemElementValueContainer]?
    ) async {
        guard !valueDidChangeThisCycle else {
            valueDidChangeThisCycle = false
            return
        }
        guard let newRange = try? await element.selectedTextRange(),
              newRange.lowerBound != .max,
              newRange.upperBound != .max else { return }
        if !newRange.isEmpty {
            guard let selected = try? await element.selectedText(), !selected.isEmpty else {
                previousSelectedRange = newRange
                previousLineNumber = (try? await element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
                try? await refreshBuffer(caret: newRange.lowerBound)
                return
            }
            previousSelectedRange = newRange
            previousLineNumber = (try? await element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
            try? await refreshBuffer(caret: newRange.lowerBound)
            output.yield(.init(
                options: [],
                identifier: "",
                // TODO: Localization
                payloads: [.speech("\(selected) selected", nil)]
            ))
        } else if newRange.lowerBound != previousSelectedRange.lowerBound {
            let delta = abs(newRange.lowerBound - previousSelectedRange.lowerBound)
            let newLine = (try? await element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
            if delta > 1 && newLine != previousLineNumber {
                // ↑/↓ navigation: speak the full new line
                guard let lineRange = try? await element.range(forLine: newLine),
                      let lineText = try? await element.string(for: lineRange) else {
                    previousSelectedRange = newRange
                    previousLineNumber = newLine
                    try? await refreshBuffer(caret: newRange.lowerBound)
                    return
                }
                previousSelectedRange = newRange
                previousLineNumber = newLine
                try? await refreshBuffer(caret: newRange.lowerBound)
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
                guard let jumped = try? await element.string(for: lo..<hi), !jumped.isEmpty else {
                    previousSelectedRange = newRange
                    previousLineNumber = (try? await element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
                    try? await refreshBuffer(caret: newRange.lowerBound)
                    return
                }
                previousSelectedRange = newRange
                previousLineNumber = (try? await element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
                try? await refreshBuffer(caret: newRange.lowerBound)
                // Use grapheme-cluster count, not UTF-16 delta, so that emoji
                // (delta == 2 UTF-16 units but 1 cluster) speaks as a character.
                let speechOptions: Output.Options = jumped.count == 1 ? [.byCharacter, .interrupt] : .interrupt
                output.yield(.init(
                    options: [],
                    identifier: "",
                    payloads: [.speech(jumped, speechOptions)]
                ))
            }
        } else {
            previousSelectedRange = newRange
            previousLineNumber = (try? await element.line(forIndex: newRange.lowerBound)) ?? previousLineNumber
            try? await refreshBuffer(caret: newRange.lowerBound)
        }
    }

    public func readAll() async throws {
        readAllTask?.cancel()
        let startIndex = previousSelectedRange.lowerBound
        readAllTask = Task {
            do {
                let totalCharacterss = (try? await element.numberOfCharacters()) ?? 0
                guard totalCharacterss > 0 else { return }
                var currentIndex = startIndex
                var isFirst = true
                while currentIndex < totalCharacterss {
                    try Task.checkCancellation()
                    guard let lineNumber = try? await element.line(forIndex: currentIndex),
                          let lineRange = try? await element.range(forLine: lineNumber),
                          !lineRange.isEmpty else {
                        currentIndex += 1
                        continue
                    }
                    // Advance past this line before the await so the loop
                    // position is correct even if the task is cancelled mid-flight.
                    currentIndex = lineRange.upperBound
                    let text = (try? await element.string(for: lineRange)) ?? ""
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue
                    }
                    await scrollToVisible(range: lineRange)
                    // Interrupt on the first chunk to stop whatever is currently
                    // speaking; subsequent chunks play back-to-back via backpressure.
                    let options: Output.Options = isFirst ? [.interrupt] : []
                    isFirst = false
                    try await directOutput.submitAndWait(job: .init(
                        options: options,
                        identifier: UUID().uuidString,
                        payloads: [.speech(text, nil)]
                    ))
                }
            } catch is CancellationError {
                // Stopped normally via stopReadAll() or focus change.
            } catch {
                logger.error("readAll: \(error.localizedDescription)")
            }
        }
    }

    public func stopReadAll() async throws {
        readAllTask?.cancel()
        readAllTask = nil
        // cancelSpeech through the interactive stream resumes any in-flight
        // submitAndWait continuation, which lets the read-all task reach its
        // next checkCancellation point and exit cleanly.
        output.yield(.init(
            options: [.interrupt],
            identifier: "cancel",
            payloads: [.cancelSpeech]
        ))
    }

    public func dispatch(command: ScreenReaderCommand) async {
        switch command {
        case .readAll:
            try? await readAll()
        case .stopReading:
            try? await stopReadAll()
        default:
            break
        }
    }

    /// Scrolls the containing scroll view so that `range` is visible.
    func scrollToVisible(range: Range<Int>) async {
        try? await element.setVisibleCharacterRange(range)
    }
}

extension TextArea: ObserverHosting {}
