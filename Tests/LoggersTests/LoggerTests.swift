import Foundation
import Loggers
import Testing

private final class SpyLogger: Logger, @unchecked Sendable {
    struct Entry: Equatable {
        let level: LoggerLevel
        let domain: LoggerDomain
        let message: String
    }

    private let lock = NSLock()
    private var storedCalls: [Entry] = []

    var calls: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return storedCalls
    }

    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        guard level != .disabled else { return }
        let rendered = message()
        lock.lock()
        defer { lock.unlock() }
        storedCalls.append(Entry(level: level, domain: domain, message: rendered))
    }
}

private struct DroppingLogger: Logger {
    func log(
        _: LoggerLevel,
        _: LoggerDomain,
        _: @autoclosure @escaping @Sendable () -> String
    ) {
        // Intentionally drops every message.
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func tick(_ value: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        stored += 1
        return value
    }
}

@Suite("Logger forwarding")
struct LoggerForwardingTests {
    @Test("verbose forwards with .verbose")
    func forwardsVerbose() {
        let logger = SpyLogger()
        logger.verbose("Test", "msg")
        #expect(logger.calls == [SpyLogger.Entry(level: .verbose, domain: "Test", message: "msg")])
    }

    @Test("debug forwards with .debug")
    func forwardsDebug() {
        let logger = SpyLogger()
        logger.debug("Test", "msg")
        #expect(logger.calls == [SpyLogger.Entry(level: .debug, domain: "Test", message: "msg")])
    }

    @Test("info forwards with .info")
    func forwardsInfo() {
        let logger = SpyLogger()
        logger.info("Test", "msg")
        #expect(logger.calls == [SpyLogger.Entry(level: .info, domain: "Test", message: "msg")])
    }

    @Test("warning forwards with .warning")
    func forwardsWarning() {
        let logger = SpyLogger()
        logger.warning("Test", "msg")
        #expect(logger.calls == [SpyLogger.Entry(level: .warning, domain: "Test", message: "msg")])
    }

    @Test("error forwards with .error")
    func forwardsError() {
        let logger = SpyLogger()
        logger.error("Test", "msg")
        #expect(logger.calls == [SpyLogger.Entry(level: .error, domain: "Test", message: "msg")])
    }

    @Test("Convenience methods remain lazy when messages are dropped")
    func conveniencesRemainLazyWhenDropped() {
        let logger = DroppingLogger()
        let counter = CallCounter()
        logger.verbose("Test", counter.tick("payload"))
        logger.debug("Test", counter.tick("payload"))
        logger.info("Test", counter.tick("payload"))
        logger.warning("Test", counter.tick("payload"))
        logger.error("Test", counter.tick("payload"))
        #expect(counter.value == 0)
    }

    @Test("Autoclosure is evaluated exactly once when implementation reads the message")
    func autoclosureEvaluatedOnceWhenRead() {
        let logger = SpyLogger()
        let counter = CallCounter()
        logger.info("Test", counter.tick("ok"))
        #expect(counter.value == 1)
    }

    @Test("Disabled is dropped without evaluating the autoclosure")
    func disabledIsDroppedWithoutEvaluation() {
        let logger = SpyLogger()
        let counter = CallCounter()
        logger.log(.disabled, "Test", counter.tick("should not be built"))
        #expect(counter.value == 0)
        #expect(logger.calls.isEmpty)
    }
}
