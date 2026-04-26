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

private func recordEvaluationAndReturn(_ counter: CallCounter, _ value: String) -> String {
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

    @Test("Filtering does not evaluate date, formatter, message, or sink")
    func filteringDoesNotEvaluate() {
        let dateCounter = CallCounter()
        let formatterCounter = CallCounter()
        let sinkCounter = CallCounter()
        let messageCounter = CallCounter()
        let logger = PrintLogger(
            minimumLevel: .error,
            dateProvider: { dateCounter.tick(); return fixedDate },
            timestampFormatter: { _ in formatterCounter.tick(); return "TS" },
            sink: { _ in sinkCounter.tick() }
        )
        logger.log(.info, "D", recordEvaluationAndReturn(messageCounter, "msg"))
        #expect(dateCounter.value == 0)
        #expect(formatterCounter.value == 0)
        #expect(sinkCounter.value == 0)
        #expect(messageCounter.value == 0)
    }

    @Test("Disabled level on a message is dropped without evaluation")
    func disabledLevelIsDropped() {
        let dateCounter = CallCounter()
        let formatterCounter = CallCounter()
        let sinkCounter = CallCounter()
        let messageCounter = CallCounter()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { dateCounter.tick(); return fixedDate },
            timestampFormatter: { _ in formatterCounter.tick(); return "TS" },
            sink: { _ in sinkCounter.tick() }
        )
        logger.log(.disabled, "D", recordEvaluationAndReturn(messageCounter, "msg"))
        #expect(dateCounter.value == 0)
        #expect(formatterCounter.value == 0)
        #expect(sinkCounter.value == 0)
        #expect(messageCounter.value == 0)
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

    @Test("Emitted message is evaluated exactly once")
    func messageEvaluatedExactlyOnce() {
        let recorder = StringRecorder()
        let counter = CallCounter()
        let logger = PrintLogger(
            minimumLevel: .verbose,
            dateProvider: { fixedDate },
            timestampFormatter: { _ in "TS" },
            sink: { recorder.append($0) }
        )
        logger.log(.info, "D", recordEvaluationAndReturn(counter, "ok"))
        #expect(counter.value == 1)
        #expect(recorder.entries == ["[TS] [info] [D] ok"])
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
