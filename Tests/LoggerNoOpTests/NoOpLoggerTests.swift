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

private func recordEvaluationAndReturn(_ counter: CallCounter, _ value: String) -> String {
    counter.tick()
    return value
}

@Suite("NoOpLogger")
struct NoOpLoggerTests {
    @Test(
        "Autoclosure is not evaluated for any LoggerLevel",
        arguments: [
            LoggerLevel.disabled,
            .verbose,
            .debug,
            .info,
            .warning,
            .error
        ]
    )
    func autoclosureNotEvaluatedForAnyLevel(level: LoggerLevel) {
        let logger = NoOpLogger()
        let counter = CallCounter()
        logger.log(level, "Test", recordEvaluationAndReturn(counter, "msg"))
        #expect(counter.value == 0)
    }

    @Test("Autoclosure is not evaluated by any convenience method")
    func conveniencesDoNotEvaluate() {
        let logger = NoOpLogger()
        let counter = CallCounter()
        logger.verbose("Test", recordEvaluationAndReturn(counter, "v"))
        logger.debug("Test", recordEvaluationAndReturn(counter, "d"))
        logger.info("Test", recordEvaluationAndReturn(counter, "i"))
        logger.warning("Test", recordEvaluationAndReturn(counter, "w"))
        logger.error("Test", recordEvaluationAndReturn(counter, "e"))
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
