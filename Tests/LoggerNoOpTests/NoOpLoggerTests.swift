import Foundation
import LoggerNoOp
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

private func recordEvaluationAndReturn<T>(_ counter: CallCounter, _ value: T) -> T {
    counter.tick()
    return value
}

@Suite("NoOpLogger")
struct NoOpLoggerTests {
    @Test(
        "Message autoclosure is not evaluated for any LoggerLevel",
        arguments: [
            LoggerLevel.disabled,
            .trace,
            .debug,
            .info,
            .notice,
            .warning,
            .error,
            .critical
        ]
    )
    func messageAutoclosureNotEvaluatedForAnyLevel(level: LoggerLevel) {
        let logger = NoOpLogger()
        let counter = CallCounter()
        logger.log(level, "Test", recordEvaluationAndReturn(counter, "msg"))
        #expect(counter.value == 0)
    }

    @Test(
        "Attributes autoclosure is not evaluated for any LoggerLevel",
        arguments: [
            LoggerLevel.disabled,
            .trace,
            .debug,
            .info,
            .notice,
            .warning,
            .error,
            .critical
        ]
    )
    func attributesAutoclosureNotEvaluatedForAnyLevel(level: LoggerLevel) {
        let logger = NoOpLogger()
        let counter = CallCounter()
        logger.log(
            level,
            "Test",
            "msg",
            attributes: recordEvaluationAndReturn(counter, [LogAttribute("k", "v")])
        )
        #expect(counter.value == 0)
    }

    @Test("Convenience methods do not evaluate message")
    func conveniencesDoNotEvaluateMessage() {
        let logger = NoOpLogger()
        let counter = CallCounter()
        logger.trace("Test", recordEvaluationAndReturn(counter, "t"))
        logger.debug("Test", recordEvaluationAndReturn(counter, "d"))
        logger.info("Test", recordEvaluationAndReturn(counter, "i"))
        logger.notice("Test", recordEvaluationAndReturn(counter, "n"))
        logger.warning("Test", recordEvaluationAndReturn(counter, "w"))
        logger.error("Test", recordEvaluationAndReturn(counter, "e"))
        logger.critical("Test", recordEvaluationAndReturn(counter, "c"))
        #expect(counter.value == 0)
    }

    @Test("Convenience methods do not evaluate attributes")
    func conveniencesDoNotEvaluateAttributes() {
        let logger = NoOpLogger()
        let counter = CallCounter()
        logger.trace("Test", "t", attributes: recordEvaluationAndReturn(counter, []))
        logger.debug("Test", "d", attributes: recordEvaluationAndReturn(counter, []))
        logger.info("Test", "i", attributes: recordEvaluationAndReturn(counter, []))
        logger.notice("Test", "n", attributes: recordEvaluationAndReturn(counter, []))
        logger.warning("Test", "w", attributes: recordEvaluationAndReturn(counter, []))
        logger.error("Test", "e", attributes: recordEvaluationAndReturn(counter, []))
        logger.critical("Test", "c", attributes: recordEvaluationAndReturn(counter, []))
        #expect(counter.value == 0)
    }

    @Test("Sendable across Task boundary")
    func sendableAcrossTask() async {
        let logger = NoOpLogger()
        let counter = CallCounter()
        await Task {
            logger.info("Test", recordEvaluationAndReturn(counter, "msg"))
        }.value
        #expect(counter.value == 0)
    }
}
