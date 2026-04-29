import Foundation
import LoggerPrint
import Loggers
import Testing

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func tick() {
        lock.lock()
        defer { lock.unlock() }
        stored += 1
    }
}

private final class StringRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []

    var entries: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(value)
    }
}

private func recordEvaluationAndReturn<T>(_ counter: CallCounter, _ value: T) -> T {
    counter.tick()
    return value
}

private let fixedDate = Date(timeIntervalSince1970: 0)

@Suite("PrintLogger")
struct PrintLoggerTests {
    @Test("Exact output with injected date and formatter")
    func exactOutputWithInjectedDateAndFormatter() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "FIXED" },
            sink: { recorder.append($0) }
        )
        logger.log(.info, "Network", "ready")
        #expect(recorder.entries == ["[FIXED] [info] [Network] ready"])
    }

    @Test("Default minimum level is warning")
    func defaultMinimumLevelIsWarning() throws {
        let recorder = StringRecorder()
        let logger = PrintLogger(sink: { recorder.append($0) })
        logger.log(.verbose, "D", "v")
        logger.log(.debug, "D", "d")
        logger.log(.info, "D", "i")
        logger.log(.warning, "D", "w")
        logger.log(.error, "D", "e")
        let lines = recorder.entries
        try #require(lines.count == 2)
        #expect(lines.allSatisfy { $0.contains("[D]") })
        #expect(lines[0].contains("[warning]"))
        #expect(lines[1].contains("[error]"))
    }

    @Test("Filtering does not evaluate date, formatter, message, attributes, or sink")
    func filteringDoesNotEvaluate() {
        let dateCounter = CallCounter()
        let formatterCounter = CallCounter()
        let sinkCounter = CallCounter()
        let messageCounter = CallCounter()
        let attributesCounter = CallCounter()
        let logger = PrintLogger(
            minimumLevel: .error,
            dateProvider: { dateCounter.tick(); return fixedDate },
            timestampFormatter: { _ in formatterCounter.tick(); return "TS" },
            sink: { _ in sinkCounter.tick() }
        )
        logger.log(
            .info,
            "D",
            recordEvaluationAndReturn(messageCounter, "msg"),
            attributes: recordEvaluationAndReturn(attributesCounter, [LogAttribute("k", "v")])
        )
        #expect(dateCounter.value == 0)
        #expect(formatterCounter.value == 0)
        #expect(sinkCounter.value == 0)
        #expect(messageCounter.value == 0)
        #expect(attributesCounter.value == 0)
    }

    @Test("Disabled level is dropped without evaluation")
    func disabledLevelIsDropped() {
        let dateCounter = CallCounter()
        let formatterCounter = CallCounter()
        let sinkCounter = CallCounter()
        let messageCounter = CallCounter()
        let attributesCounter = CallCounter()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { dateCounter.tick(); return fixedDate },
            timestampFormatter: { _ in formatterCounter.tick(); return "TS" },
            sink: { _ in sinkCounter.tick() }
        )
        logger.log(
            .disabled,
            "D",
            recordEvaluationAndReturn(messageCounter, "msg"),
            attributes: recordEvaluationAndReturn(attributesCounter, [LogAttribute("k", "v")])
        )
        #expect(dateCounter.value == 0)
        #expect(formatterCounter.value == 0)
        #expect(sinkCounter.value == 0)
        #expect(messageCounter.value == 0)
        #expect(attributesCounter.value == 0)
    }

    @Test("Convenience methods route to the corresponding level")
    func convenienceMethods() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        logger.verbose("D", "v")
        logger.debug("D", "d")
        logger.info("D", "i")
        logger.warning("D", "w")
        logger.error("D", "e")
        #expect(recorder.entries == [
            "[TS] [verbose] [D] v",
            "[TS] [debug] [D] d",
            "[TS] [info] [D] i",
            "[TS] [warning] [D] w",
            "[TS] [error] [D] e"
        ])
    }

    @Test("Message and attributes are evaluated exactly once on emit")
    func payloadEvaluatedExactlyOnce() {
        let recorder = StringRecorder()
        let messageCounter = CallCounter()
        let attributesCounter = CallCounter()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        logger.log(
            .info,
            "D",
            recordEvaluationAndReturn(messageCounter, "ok"),
            attributes: recordEvaluationAndReturn(attributesCounter, [LogAttribute("k", "v")])
        )
        #expect(messageCounter.value == 1)
        #expect(attributesCounter.value == 1)
        #expect(recorder.entries == ["[TS] [info] [D] ok {k=v}"])
    }

    // MARK: Privacy redaction

    @Test("Public message segment renders verbatim")
    func publicSegmentRendersVerbatim() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        let name = "Alice"
        logger.info("Auth", "User \(name) signed in")
        #expect(recorder.entries == ["[TS] [info] [Auth] User Alice signed in"])
    }

    @Test("Private message segment renders as <private>")
    func privateSegmentRedacted() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        let name = "Alice"
        logger.info("Auth", "User \(name, privacy: .private) signed in")
        #expect(recorder.entries == ["[TS] [info] [Auth] User <private> signed in"])
    }

    @Test("Sensitive message segment renders as <redacted>")
    func sensitiveSegmentRedacted() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        let token = "ey..."
        logger.info("Auth", "Token \(token, privacy: .sensitive)")
        #expect(recorder.entries == ["[TS] [info] [Auth] Token <redacted>"])
    }

    @Test("Public attribute renders as key=value")
    func publicAttributeRenders() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        logger.info("Net", "ok", attributes: [LogAttribute("path", "/v1/users")])
        #expect(recorder.entries == ["[TS] [info] [Net] ok {path=/v1/users}"])
    }

    @Test("Private attribute renders as key=<private>")
    func privateAttributeRedacted() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        logger.info(
            "Auth",
            "ok",
            attributes: [LogAttribute("user", "alice", privacy: .private)]
        )
        #expect(recorder.entries == ["[TS] [info] [Auth] ok {user=<private>}"])
    }

    @Test("Sensitive attribute renders as key=<redacted>")
    func sensitiveAttributeRedacted() {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        logger.info(
            "Auth",
            "ok",
            attributes: [LogAttribute("token", "ey...", privacy: .sensitive)]
        )
        #expect(recorder.entries == ["[TS] [info] [Auth] ok {token=<redacted>}"])
    }

    @Test("Default ISO 8601 formatter emits UTC with fractional seconds")
    func defaultISO8601Format() {
        let rendered = PrintLogger.defaultTimestampFormatter(fixedDate)
        #expect(rendered == "1970-01-01T00:00:00.000Z")
    }

    @Test("MinimumLevel allCases is in declaration order")
    func minimumLevelAllCasesOrder() {
        #expect(PrintLogger.MinimumLevel.allCases == [
            .verbose, .debug, .info, .warning, .error
        ])
    }

    @Test(
        "Threshold filtering pins emitted levels for each MinimumLevel",
        arguments: [
            (PrintLogger.MinimumLevel.verbose, [LoggerLevel.verbose, .debug, .info, .warning, .error]),
            (PrintLogger.MinimumLevel.debug, [LoggerLevel.debug, .info, .warning, .error]),
            (PrintLogger.MinimumLevel.info, [LoggerLevel.info, .warning, .error]),
            (PrintLogger.MinimumLevel.warning, [LoggerLevel.warning, .error]),
            (PrintLogger.MinimumLevel.error, [LoggerLevel.error])
        ]
    )
    func thresholdEmissionMatrix(threshold: PrintLogger.MinimumLevel, expected: [LoggerLevel]) {
        let recorder = StringRecorder()
        let logger = PrintLogger(
            minimumLevel: threshold,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        let allSeverities: [LoggerLevel] = [.verbose, .debug, .info, .warning, .error]
        for level in allSeverities {
            logger.log(level, "D", "msg")
        }
        let expectedLines = expected.map { "[TS] [\($0)] [D] msg" }
        #expect(recorder.entries == expectedLines)
    }
}
