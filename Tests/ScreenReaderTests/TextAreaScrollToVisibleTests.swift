//
//  TextAreaScrollToVisibleTests.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Testing
import AccessibilityElement
import AccessibilityElementMocks
import os
@testable import ScreenReader

struct TextAreaScrollToVisibleTests {

    @Test("scrollToVisible calls setVisibleCharacterRange with the correct range")
    func scrollCallsSetVisibleCharacterRange() async throws {
        let captured = OSAllocatedUnfairLock<Range<Int>?>(initialState: nil)
        let element = MockElement(storage: [.numberOfCharacters: 0])
        element.setVisibleCharacterRangeHandler = { range in
            captured.withLock { $0 = range }
        }
        let recording = RecordingOutputContext()
        let textArea = try await makeTextArea(element: element, recording: recording)

        await textArea.scrollToVisible(range: 5..<10)

        #expect(captured.withLock { $0 } == 5..<10)
    }

    @Test("scrollToVisible does not propagate errors from setVisibleCharacterRange")
    func scrollSwallowsErrors() async throws {
        let element = MockElement(storage: [.numberOfCharacters: 0])
        element.setVisibleCharacterRangeHandler = { _ in throw ElementError.noValue }
        let recording = RecordingOutputContext()
        let textArea = try await makeTextArea(element: element, recording: recording)

        // Must not throw or crash.
        await textArea.scrollToVisible(range: 0..<5)
    }

    @Test("readAll calls scrollToVisible once per non-blank line, in order")
    func readAllScrollsEachLine() async throws {
        let scrolled = OSAllocatedUnfairLock<[Range<Int>]>(initialState: [])
        let element = MockElement(storage: [.numberOfCharacters: 11])
        element.lineForIndexHandler = { index in index < 6 ? 0 : 1 }
        element.rangeForLineHandler = { line in line == 0 ? 0..<6 : 6..<11 }
        element.stringForHandler = { range in
            switch range {
            case 0..<6: return "Hello\n"
            case 6..<11: return "World"
            default: throw ElementError.noValue
            }
        }
        element.setVisibleCharacterRangeHandler = { range in
            scrolled.withLock { $0.append(range) }
        }
        let recording = RecordingOutputContext()
        let textArea = try await makeTextArea(element: element, recording: recording)

        try await textArea.readAll()

        // Drain both submitted jobs to ensure readAll has finished both lines.
        var jobs: [Output.Job] = []
        for await job in recording.jobs.prefix(2) {
            jobs.append(job)
        }
        #expect(jobs.count == 2)
        #expect(scrolled.withLock { $0 } == [0..<6, 6..<11])
    }
}
