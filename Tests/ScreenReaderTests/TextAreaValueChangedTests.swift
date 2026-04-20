//
//  TextAreaValueChangedTests.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Testing
import AccessibilityElement
import AccessibilityElementMocks
@testable import ScreenReader

// MARK: - Helpers

// valueChanged yields to the buffered output stream, not directOutput, so this
// helper returns both the TextArea and the buffered jobs stream to the caller.
func makeTextArea(
    element: MockElement,
    source: MockNotificationSource
) async throws -> (TextArea<MockObserver>, AsyncStream<Output.Job>) {
    let executor = RunLoopExecutor()
    executor.start()
    let (jobs, buffered) = AsyncStream<Output.Job>.makeStream()
    let textArea = try await TextArea(
        element: element,
        output: .init(
            directOutput: RecordingOutputContext(),
            bufferedOutput: buffered
        ),
        observer: ApplicationObserver(observer: MockObserver(source: source)),
        executor: executor
    )
    return (textArea, jobs)
}

// MARK: - valueChanged

struct TextAreaValueChangedTests {

    @Test("Inserting an ASCII character speaks that character")
    func asciiInsertion() async throws {
        // Initial state: "Hello" (5 chars), caret at end
        let element = MockElement(storage: [
            .numberOfCharacters: 5,
            .selectedTextRange: 5..<5,
        ])
        element.stringForHandler = { range in
            if range == 0..<5 { return "Hello" }
            throw ElementError.noValue
        }

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        // Simulate typing 'W': "Hello" → "HelloW", caret advances to 6
        element.set(6, for: .numberOfCharacters)
        element.set(6..<6, for: .selectedTextRange)
        element.stringForHandler = { range in
            switch range {
            case 0..<5: return "Hello"
            case 5..<6: return "W"
            default: throw ElementError.noValue
            }
        }

        source.emit(.valueChanged, element: element)

        var collectedJobs: [Output.Job] = []
        for await job in jobs.prefix(1) {
            collectedJobs.append(job)
        }
        guard let job = collectedJobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, _) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        #expect(text == "W")
    }

    @Test("Deleting an ASCII character speaks that character")
    func asciiDeletion() async throws {
        // Initial state: "Hello" (5 chars), caret at end
        let element = MockElement(storage: [
            .numberOfCharacters: 5,
            .selectedTextRange: 5..<5,
        ])
        element.stringForHandler = { range in
            if range == 0..<5 { return "Hello" }
            throw ElementError.noValue
        }

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        // Simulate pressing backspace: "Hello" → "Hell", caret retreats to 4
        element.set(4, for: .numberOfCharacters)
        element.set(4..<4, for: .selectedTextRange)

        source.emit(.valueChanged, element: element)

        var collectedJobs: [Output.Job] = []
        for await job in jobs.prefix(1) {
            collectedJobs.append(job)
        }
        guard let job = collectedJobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, _) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        #expect(text == "o")
    }

    @Test("Deleting an emoji speaks only the emoji, not following characters")
    func emojiDeletion() async throws {
        // "Hi👋!" has NSString length 5: H(1) i(1) 👋(2 surrogate units) !(1).
        // Swift sees 4 grapheme clusters; AX reports UTF-16 code-unit positions.
        let element = MockElement(storage: [
            .numberOfCharacters: 5,
            .selectedTextRange: 5..<5,
        ])
        element.stringForHandler = { range in
            if range == 0..<5 { return "Hi👋!" }
            throw ElementError.noValue
        }

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        // Simulate deleting 👋: "Hi👋!" → "Hi!", caret moves from 5 to 2.
        // AX delta = -2 (two UTF-16 units removed), deletedStart = 2.
        element.set(3, for: .numberOfCharacters)
        element.set(2..<2, for: .selectedTextRange)

        source.emit(.valueChanged, element: element)

        var collectedJobs: [Output.Job] = []
        for await job in jobs.prefix(1) {
            collectedJobs.append(job)
        }
        guard let job = collectedJobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, _) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        // Without the UTF-16 fix this would be "👋!" (two grapheme clusters).
        #expect(text == "👋")
    }
}
