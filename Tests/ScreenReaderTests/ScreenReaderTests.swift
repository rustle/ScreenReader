import Testing
import AccessibilityElement
import AccessibilityElementMocks
@testable import ScreenReader

// MARK: - Helpers

func makeTextArea(
    element: MockElement,
    recording: RecordingOutputContext
) async throws -> TextArea<MockObserver> {
    let executor = RunLoopExecutor()
    executor.start()
    let (_, buffered) = AsyncStream<Output.Job>.makeStream()
    return try await TextArea(
        element: element,
        output: .init(directOutput: recording, bufferedOutput: buffered),
        observer: ApplicationObserver(observer: MockObserver()),
        executor: executor
    )
}

// MARK: - readAll

struct TextAreaReadAllTests {

    @Test("Empty document produces no output")
    func emptyDocument() async throws {
        let element = MockElement(storage: [.numberOfCharacters: 0])
        let recording = RecordingOutputContext()
        let textArea = try await makeTextArea(element: element, recording: recording)

        try await textArea.readAll()

        // The readAll task exits before its first await (guard totalChars > 0
        // else { return }), so one yield is sufficient to let it run to
        // completion before we check that nothing was submitted.
        await Task.yield()
        #expect(await recording.submitCount == 0)
    }

    @Test("Single line speaks the text with interrupt")
    func singleLine() async throws {
        let element = MockElement(storage: [.numberOfCharacters: 5])
        element.lineForIndexHandler = { _ in 0 }
        element.rangeForLineHandler = { _ in 0..<5 }
        element.stringForHandler = { _ in "Hello" }
        let recording = RecordingOutputContext()
        let textArea = try await makeTextArea(element: element, recording: recording)

        try await textArea.readAll()

        var jobs: [Output.Job] = []
        for await job in recording.jobs.prefix(1) {
            jobs.append(job)
        }
        guard let job = jobs.first else {
            Issue.record("Expected one job")
            return
        }
        guard case .speech(let text, _) = job.payloads.first else {
            Issue.record("Expected speech payload")
            return
        }
        #expect(text == "Hello")
        #expect(job.options == .interrupt)
    }

    @Test("Multiple lines are spoken in order; first gets interrupt, rest do not")
    func multipleLines() async throws {
        // "Hello\n" occupies range 0..<6; "World" occupies 6..<11.
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
        let recording = RecordingOutputContext()
        let textArea = try await makeTextArea(element: element, recording: recording)

        try await textArea.readAll()

        var jobs: [Output.Job] = []
        for await job in recording.jobs.prefix(2) {
            jobs.append(job)
        }
        #expect(jobs.count == 2)
        guard case .speech(let first, _) = jobs[0].payloads.first,
              case .speech(let second, _) = jobs[1].payloads.first else {
            Issue.record("Expected speech payloads")
            return
        }
        #expect(first == "Hello\n")
        #expect(second == "World")
        #expect(jobs[0].options == .interrupt)
        #expect(jobs[1].options == [])
    }

    @Test("Blank lines are skipped")
    func blankLinesSkipped() async throws {
        // "Hello\n" (0..<6), "\n" (6..<7, blank), "World" (7..<12)
        let element = MockElement(storage: [.numberOfCharacters: 12])
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
            switch range {
            case 0..<6: return "Hello\n"
            case 6..<7: return "\n"
            case 7..<12: return "World"
            default: throw ElementError.noValue
            }
        }
        let recording = RecordingOutputContext()
        let textArea = try await makeTextArea(element: element, recording: recording)

        try await textArea.readAll()

        var jobs: [Output.Job] = []
        for await job in recording.jobs.prefix(2) {
            jobs.append(job)
        }
        #expect(jobs.count == 2)
        guard case .speech(let first, _) = jobs[0].payloads.first,
              case .speech(let second, _) = jobs[1].payloads.first else {
            Issue.record("Expected speech payloads")
            return
        }
        #expect(first == "Hello\n")
        #expect(second == "World")
    }
}
