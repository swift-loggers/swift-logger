import Foundation
import Loggers
import Testing

private final class SpyLogger: Logger, @unchecked Sendable {
    struct Entry: Equatable {
        let level: LoggerLevel
        let domain: LoggerDomain
        let message: LogMessage
        let attributes: [LogAttribute]
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
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute]
    ) {
        guard level != .disabled else { return }
        let resolvedMessage = message()
        let resolvedAttributes = attributes()
        lock.lock()
        defer { lock.unlock() }
        storedCalls.append(
            Entry(
                level: level,
                domain: domain,
                message: resolvedMessage,
                attributes: resolvedAttributes
            )
        )
    }
}

private struct DroppingLogger: Logger {
    func log(
        _: LoggerLevel,
        _: LoggerDomain,
        _: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes _: @autoclosure @escaping @Sendable () -> [LogAttribute]
    ) {
        // Intentionally drops every entry.
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

    @discardableResult
    func tick<T>(_ value: T) -> T {
        lock.lock()
        defer { lock.unlock() }
        stored += 1
        return value
    }
}

extension LoggerDomain {
    fileprivate static let network: LoggerDomain = "Network"
}

@Suite("Logger forwarding")
struct LoggerForwardingTests {
    // MARK: String convenience overloads

    @Test("verbose(String) forwards as .text segment at .verbose")
    func forwardsVerboseString() {
        let logger = SpyLogger()
        logger.verbose("Test", "msg")
        #expect(logger.calls == [
            SpyLogger.Entry(
                level: .verbose,
                domain: "Test",
                message: "msg",
                attributes: []
            )
        ])
    }

    @Test("debug(String) forwards as .text segment at .debug")
    func forwardsDebugString() {
        let logger = SpyLogger()
        logger.debug("Test", "msg")
        #expect(logger.calls == [
            SpyLogger.Entry(
                level: .debug,
                domain: "Test",
                message: "msg",
                attributes: []
            )
        ])
    }

    @Test("info(String) forwards as .text segment at .info")
    func forwardsInfoString() {
        let logger = SpyLogger()
        logger.info("Test", "msg")
        #expect(logger.calls == [
            SpyLogger.Entry(
                level: .info,
                domain: "Test",
                message: "msg",
                attributes: []
            )
        ])
    }

    @Test("warning(String) forwards as .text segment at .warning")
    func forwardsWarningString() {
        let logger = SpyLogger()
        logger.warning("Test", "msg")
        #expect(logger.calls == [
            SpyLogger.Entry(
                level: .warning,
                domain: "Test",
                message: "msg",
                attributes: []
            )
        ])
    }

    @Test("error(String) forwards as .text segment at .error")
    func forwardsErrorString() {
        let logger = SpyLogger()
        logger.error("Test", "msg")
        #expect(logger.calls == [
            SpyLogger.Entry(
                level: .error,
                domain: "Test",
                message: "msg",
                attributes: []
            )
        ])
    }

    @Test("Existing call site logger.info(.network, msg) still compiles unchanged")
    func existingCallSiteCompiles() {
        let logger = SpyLogger()
        logger.info(.network, "Request started")
        #expect(logger.calls.count == 1)
        #expect(logger.calls[0].message == "Request started")
    }

    // MARK: Lazy guarantees

    @Test("String convenience methods remain lazy when entries are dropped")
    func stringConveniencesRemainLazyWhenDropped() {
        let logger = DroppingLogger()
        let counter = CallCounter()
        logger.verbose("Test", counter.tick("payload"))
        logger.debug("Test", counter.tick("payload"))
        logger.info("Test", counter.tick("payload"))
        logger.warning("Test", counter.tick("payload"))
        logger.error("Test", counter.tick("payload"))
        #expect(counter.value == 0)
    }

    @Test("LogMessage convenience methods remain lazy when entries are dropped")
    func logMessageConveniencesRemainLazyWhenDropped() {
        let logger = DroppingLogger()
        let counter = CallCounter()
        logger.verbose("Test", counter.tick(LogMessage(segments: [LogSegment("v")])))
        logger.debug("Test", counter.tick(LogMessage(segments: [LogSegment("d")])))
        logger.info("Test", counter.tick(LogMessage(segments: [LogSegment("i")])))
        logger.warning("Test", counter.tick(LogMessage(segments: [LogSegment("w")])))
        logger.error("Test", counter.tick(LogMessage(segments: [LogSegment("e")])))
        #expect(counter.value == 0)
    }

    @Test("Attributes autoclosure is lazy when entries are dropped")
    func attributesAreLazyWhenDropped() {
        let logger = DroppingLogger()
        let counter = CallCounter()
        logger.info(
            "Test",
            "msg",
            attributes: counter.tick([LogAttribute("k", "v")])
        )
        #expect(counter.value == 0)
    }

    @Test("Disabled level drops without evaluating message or attributes")
    func disabledIsDroppedWithoutEvaluation() {
        let logger = SpyLogger()
        let messageCounter = CallCounter()
        let attributesCounter = CallCounter()
        logger.log(
            .disabled,
            "Test",
            messageCounter.tick(LogMessage(stringLiteral: "no")),
            attributes: attributesCounter.tick([LogAttribute("k", "v")])
        )
        #expect(messageCounter.value == 0)
        #expect(attributesCounter.value == 0)
        #expect(logger.calls.isEmpty)
    }

    @Test("Message autoclosure evaluated exactly once when entry is emitted")
    func messageEvaluatedOnceOnEmit() {
        let logger = SpyLogger()
        let counter = CallCounter()
        logger.info("Test", counter.tick("ok"))
        #expect(counter.value == 1)
    }

    @Test("Attributes autoclosure evaluated exactly once when entry is emitted")
    func attributesEvaluatedOnceOnEmit() {
        let logger = SpyLogger()
        let counter = CallCounter()
        logger.info(
            "Test",
            "msg",
            attributes: counter.tick([LogAttribute("k", "v")])
        )
        #expect(counter.value == 1)
    }
}

// MARK: - LogMessage convenience per-level forwarding

@Suite("Logger LogMessage convenience overloads")
struct LoggerLogMessageConvenienceTests {
    @Test("verbose(LogMessage) forwards at .verbose")
    func forwardsVerbose() {
        let logger = LogMessageSpyLogger()
        let message = LogMessage(segments: [LogSegment("v")])
        logger.verbose("Test", message)
        #expect(logger.calls == [
            LogMessageSpyLogger.Entry(
                level: .verbose,
                domain: "Test",
                message: message,
                attributes: []
            )
        ])
    }

    @Test("debug(LogMessage) forwards at .debug")
    func forwardsDebug() {
        let logger = LogMessageSpyLogger()
        let message = LogMessage(segments: [LogSegment("d")])
        logger.debug("Test", message)
        #expect(logger.calls == [
            LogMessageSpyLogger.Entry(
                level: .debug,
                domain: "Test",
                message: message,
                attributes: []
            )
        ])
    }

    @Test("info(LogMessage) forwards at .info")
    func forwardsInfo() {
        let logger = LogMessageSpyLogger()
        let message = LogMessage(segments: [LogSegment("i")])
        logger.info("Test", message)
        #expect(logger.calls == [
            LogMessageSpyLogger.Entry(
                level: .info,
                domain: "Test",
                message: message,
                attributes: []
            )
        ])
    }

    @Test("warning(LogMessage) forwards at .warning")
    func forwardsWarning() {
        let logger = LogMessageSpyLogger()
        let message = LogMessage(segments: [LogSegment("w")])
        logger.warning("Test", message)
        #expect(logger.calls == [
            LogMessageSpyLogger.Entry(
                level: .warning,
                domain: "Test",
                message: message,
                attributes: []
            )
        ])
    }

    @Test("error(LogMessage) forwards at .error")
    func forwardsError() {
        let logger = LogMessageSpyLogger()
        let message = LogMessage(segments: [LogSegment("e")])
        logger.error("Test", message)
        #expect(logger.calls == [
            LogMessageSpyLogger.Entry(
                level: .error,
                domain: "Test",
                message: message,
                attributes: []
            )
        ])
    }

    @Test("LogMessage convenience forwards attributes when provided")
    func forwardsAttributes() {
        let logger = LogMessageSpyLogger()
        let message = LogMessage(segments: [LogSegment("m")])
        logger.info(
            "Test",
            message,
            attributes: [LogAttribute("k", "v")]
        )
        #expect(logger.calls.count == 1)
        #expect(logger.calls[0].attributes == [LogAttribute("k", "v")])
    }
}

private final class LogMessageSpyLogger: Logger, @unchecked Sendable {
    struct Entry: Equatable {
        let level: LoggerLevel
        let domain: LoggerDomain
        let message: LogMessage
        let attributes: [LogAttribute]
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
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute]
    ) {
        guard level != .disabled else { return }
        let resolvedMessage = message()
        let resolvedAttributes = attributes()
        lock.lock()
        defer { lock.unlock() }
        storedCalls.append(
            Entry(
                level: level,
                domain: domain,
                message: resolvedMessage,
                attributes: resolvedAttributes
            )
        )
    }
}
