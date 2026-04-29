import Foundation
import LoggerFiltering
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

private final class ForwardingLogger: Logger, @unchecked Sendable {
    struct Entry: Equatable {
        let level: LoggerLevel
        let domain: LoggerDomain
        let message: LogMessage
        let attributes: [LogAttribute]
    }

    private let lock = NSLock()
    private var stored: [Entry] = []

    var calls: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return stored
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
        stored.append(
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

private func recordEvaluationAndReturn<T>(_ counter: CallCounter, _ value: T) -> T {
    counter.tick()
    return value
}

@Suite("DomainFilteredLogger")
struct DomainFilteredLoggerTests {
    @Test("MinimumLevel allCases is in declaration order")
    func minimumLevelAllCasesOrder() {
        #expect(DomainFilteredLogger.MinimumLevel.allCases == [
            .verbose, .debug, .info, .warning, .error
        ])
    }

    @Test("MinimumLevel default is warning")
    func minimumLevelDefault() {
        #expect(DomainFilteredLogger.MinimumLevel.defaultLevel == .warning)
    }

    @Test("Disabled entry is dropped without evaluation and without upstream call")
    func disabledEntryIsDropped() {
        let upstream = ForwardingLogger()
        let messageCounter = CallCounter()
        let attributesCounter = CallCounter()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .verbose
        )
        filtered.log(
            .disabled,
            "D",
            recordEvaluationAndReturn(messageCounter, "msg"),
            attributes: recordEvaluationAndReturn(attributesCounter, [LogAttribute("k", "v")])
        )
        #expect(messageCounter.value == 0)
        #expect(attributesCounter.value == 0)
        #expect(upstream.calls.isEmpty)
    }

    @Test("Below-threshold entry is dropped without evaluation and without upstream call")
    func belowThresholdIsDropped() {
        let upstream = ForwardingLogger()
        let messageCounter = CallCounter()
        let attributesCounter = CallCounter()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .error
        )
        filtered.log(
            .info,
            "D",
            recordEvaluationAndReturn(messageCounter, "msg"),
            attributes: recordEvaluationAndReturn(attributesCounter, [LogAttribute("k", "v")])
        )
        #expect(messageCounter.value == 0)
        #expect(attributesCounter.value == 0)
        #expect(upstream.calls.isEmpty)
    }

    @Test("Allowed entry is forwarded to upstream with same level, domain, message, and attributes")
    func allowedEntryForwarded() {
        let upstream = ForwardingLogger()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .verbose
        )
        filtered.log(
            .info,
            "Network",
            "ping",
            attributes: [LogAttribute("path", "/v1/users")]
        )
        #expect(upstream.calls == [
            ForwardingLogger.Entry(
                level: .info,
                domain: "Network",
                message: "ping",
                attributes: [LogAttribute("path", "/v1/users")]
            )
        ])
    }

    @Test("Allowed entry is not evaluated by the filter when upstream drops it")
    func allowedEntryNotEvaluatedByFilter() {
        let upstream = DroppingLogger()
        let messageCounter = CallCounter()
        let attributesCounter = CallCounter()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .verbose
        )
        filtered.log(
            .info,
            "D",
            recordEvaluationAndReturn(messageCounter, "msg"),
            attributes: recordEvaluationAndReturn(attributesCounter, [LogAttribute("k", "v")])
        )
        #expect(messageCounter.value == 0)
        #expect(attributesCounter.value == 0)
    }

    @Test("Per-domain override raises threshold above the default")
    func perDomainOverrideRaisesThreshold() {
        let upstream = ForwardingLogger()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .verbose,
            domainMinimumLevels: ["Network": .error]
        )
        filtered.log(.info, "Network", "raised: should be dropped")
        filtered.log(.info, "Other", "default: should pass")
        #expect(upstream.calls.map(\.domain) == ["Other"])
    }

    @Test("Per-domain override lowers threshold below the default")
    func perDomainOverrideLowersThreshold() {
        let upstream = ForwardingLogger()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .error,
            domainMinimumLevels: ["Network": .verbose]
        )
        filtered.log(.info, "Network", "lowered: should pass")
        filtered.log(.info, "Other", "default: should be dropped")
        #expect(upstream.calls.map(\.domain) == ["Network"])
    }

    @Test("Unknown domain falls back to default when overrides are non-empty")
    func unknownDomainFallback() {
        let upstream = ForwardingLogger()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .warning,
            domainMinimumLevels: ["Network": .verbose, "Database": .error]
        )
        filtered.log(.info, "Unknown", "below default warning, dropped")
        filtered.log(.warning, "Unknown", "at default warning, passed")
        #expect(upstream.calls.map(\.level) == [.warning])
    }

    @Test(
        "Threshold filtering pins emitted levels for each MinimumLevel",
        arguments: [
            (DomainFilteredLogger.MinimumLevel.verbose, [LoggerLevel.verbose, .debug, .info, .warning, .error]),
            (DomainFilteredLogger.MinimumLevel.debug, [LoggerLevel.debug, .info, .warning, .error]),
            (DomainFilteredLogger.MinimumLevel.info, [LoggerLevel.info, .warning, .error]),
            (DomainFilteredLogger.MinimumLevel.warning, [LoggerLevel.warning, .error]),
            (DomainFilteredLogger.MinimumLevel.error, [LoggerLevel.error])
        ]
    )
    func thresholdEmissionMatrix(threshold: DomainFilteredLogger.MinimumLevel, expected: [LoggerLevel]) {
        let upstream = ForwardingLogger()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: threshold
        )
        let allSeverities: [LoggerLevel] = [.verbose, .debug, .info, .warning, .error]
        for level in allSeverities {
            filtered.log(level, "D", "msg")
        }
        let levels = upstream.calls.map(\.level)
        #expect(levels == expected)
    }
}
