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
        let message: String
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
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        guard level != .disabled else { return }
        let rendered = message()
        lock.lock()
        defer { lock.unlock() }
        stored.append(Entry(level: level, domain: domain, message: rendered))
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

private func recordEvaluationAndReturn(_ counter: CallCounter, _ value: String) -> String {
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

    @Test("Disabled message is dropped without evaluation and without upstream call")
    func disabledMessageIsDropped() {
        let upstream = ForwardingLogger()
        let counter = CallCounter()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .verbose
        )
        filtered.log(.disabled, "D", recordEvaluationAndReturn(counter, "msg"))
        #expect(counter.value == 0)
        #expect(upstream.calls.isEmpty)
    }

    @Test("Below-threshold message is dropped without evaluation and without upstream call")
    func belowThresholdIsDropped() {
        let upstream = ForwardingLogger()
        let counter = CallCounter()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .error
        )
        filtered.log(.info, "D", recordEvaluationAndReturn(counter, "msg"))
        #expect(counter.value == 0)
        #expect(upstream.calls.isEmpty)
    }

    @Test("Allowed message is forwarded to upstream with same level, domain, and message")
    func allowedMessageForwarded() {
        let upstream = ForwardingLogger()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .verbose
        )
        filtered.log(.info, "Network", "ping")
        #expect(upstream.calls == [
            ForwardingLogger.Entry(level: .info, domain: "Network", message: "ping")
        ])
    }

    @Test("Allowed message is not evaluated by the filter when upstream drops it")
    func allowedMessageNotEvaluatedByFilter() {
        let upstream = DroppingLogger()
        let counter = CallCounter()
        let filtered = DomainFilteredLogger(
            upstream: upstream,
            defaultMinimumLevel: .verbose
        )
        filtered.log(.info, "D", recordEvaluationAndReturn(counter, "msg"))
        #expect(counter.value == 0)
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
        #expect(upstream.calls == [
            ForwardingLogger.Entry(level: .info, domain: "Other", message: "default: should pass")
        ])
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
        #expect(upstream.calls == [
            ForwardingLogger.Entry(level: .info, domain: "Network", message: "lowered: should pass")
        ])
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
        #expect(upstream.calls == [
            ForwardingLogger.Entry(level: .warning, domain: "Unknown", message: "at default warning, passed")
        ])
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
