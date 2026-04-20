//
//  TextAreaSelectedTextChangedTests.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Testing
import AccessibilityElement
import AccessibilityElementMocks
@testable import ScreenReader

struct TextAreaSelectedTextChangedTests {

    @Test("Moving cursor right by one ASCII character speaks that character")
    func asciiCharacterRight() async throws {
        let element = MockElement(storage: [
            .numberOfCharacters: 5,
            .selectedTextRange: 0..<0,
        ])
        element.lineForIndexHandler = { _ in 0 }
        element.stringForHandler = { range in
            if range == 0..<1 { return "H" }
            if range == 0..<5 { return "Hello" }
            throw ElementError.noValue
        }

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        element.set(1..<1, for: .selectedTextRange)

        source.emit(.selectedTextChanged, element: element)

        var collectedJobs: [Output.Job] = []
        for await job in jobs.prefix(1) {
            collectedJobs.append(job)
        }
        guard let job = collectedJobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, let options) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        #expect(text == "H")
        #expect(options == [.byCharacter, .interrupt])
    }

    @Test("Moving cursor right over an emoji speaks the emoji as a single character")
    func emojiCharacterRight() async throws {
        // "Hi👋!" has NSString length 5: H(1) i(1) 👋(2 surrogate units) !(1).
        // Pressing right arrow at caret position 2 (before 👋) advances to
        // position 4 (after 👋) — a UTF-16 delta of 2 even though only one
        // grapheme cluster was traversed.
        let element = MockElement(storage: [
            .numberOfCharacters: 5,
            .selectedTextRange: 2..<2,
        ])
        element.lineForIndexHandler = { _ in 0 }
        element.stringForHandler = { range in
            if range == 2..<4 { return "👋" }
            if range == 0..<5 { return "Hi👋!" }
            throw ElementError.noValue
        }

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        element.set(4..<4, for: .selectedTextRange)

        source.emit(.selectedTextChanged, element: element)

        var collectedJobs: [Output.Job] = []
        for await job in jobs.prefix(1) {
            collectedJobs.append(job)
        }
        guard let job = collectedJobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, let options) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        // Without the grapheme-cluster fix, delta == 2 ≠ 1 gives .interrupt
        // instead of [.byCharacter, .interrupt].
        #expect(text == "👋")
        #expect(options == [.byCharacter, .interrupt])
    }

    @Test("Selecting text speaks the selection with 'selected' suffix")
    func textSelection() async throws {
        let element = MockElement(storage: [
            .numberOfCharacters: 5,
            .selectedTextRange: 0..<0,
        ])

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        element.set(0..<5, for: .selectedTextRange)
        element.set("Hello", for: .selectedText)

        source.emit(.selectedTextChanged, element: element)

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
        #expect(text == "Hello selected")
    }

    @Test("Moving cursor to a different line speaks that line")
    func lineNavigation() async throws {
        // "Hello\nWorld" — NSString length 11.
        let element = MockElement(storage: [
            .numberOfCharacters: 11,
            .selectedTextRange: 0..<0,
        ])
        element.lineForIndexHandler = { index in index < 6 ? 0 : 1 }
        element.rangeForLineHandler = { line in line == 0 ? 0..<6 : 6..<11 }
        element.stringForHandler = { range in
            if range == 6..<11 { return "World" }
            if range == 0..<11 { return "Hello\nWorld" }
            throw ElementError.noValue
        }

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        // Simulate pressing ↓: caret moves from 0 (line 0) to 6 (line 1).
        element.set(6..<6, for: .selectedTextRange)

        source.emit(.selectedTextChanged, element: element)

        var collectedJobs: [Output.Job] = []
        for await job in jobs.prefix(1) {
            collectedJobs.append(job)
        }
        guard let job = collectedJobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, let options) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        #expect(text == "World")
        #expect(options == .interrupt)
    }

    @Test("Moving cursor to a blank line speaks 'blank'")
    func blankLineNavigation() async throws {
        // "Hello\n\nWorld" — NSString length 12.
        let element = MockElement(storage: [
            .numberOfCharacters: 12,
            .selectedTextRange: 0..<0,
        ])
        element.lineForIndexHandler = { index in
            if index < 6 { return 0 }
            if index < 7 { return 1 }
            return 2
        }
        element.rangeForLineHandler = { line in
            switch line {
            case 0: return 0..<6
            case 1: return 6..<7
            default: return 7..<12
            }
        }
        element.stringForHandler = { range in
            if range == 6..<7 { return "\n" }
            if range == 0..<12 { return "Hello\n\nWorld" }
            throw ElementError.noValue
        }

        let source = MockNotificationSource()
        let (textArea, jobs) = try await makeTextArea(element: element, source: source)
        try await textArea.focus()
        try await textArea.start()

        // Simulate pressing ↓: caret moves from 0 (line 0) to 6 (line 1, blank).
        element.set(6..<6, for: .selectedTextRange)

        source.emit(.selectedTextChanged, element: element)

        var collectedJobs: [Output.Job] = []
        for await job in jobs.prefix(1) {
            collectedJobs.append(job)
        }
        guard let job = collectedJobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, let options) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        #expect(text == "blank")
        #expect(options == .interrupt)
    }
}
