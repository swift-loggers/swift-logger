import Loggers

/// A `Logger` that applies a per-domain severity threshold and forwards
/// surviving messages to an upstream `Logger`.
///
/// `DomainFilteredLogger` is a decorator: it does not render messages
/// itself. After the threshold check it delegates to its upstream
/// logger, which can be any `Logger` value (a print backend, a recording
/// logger in tests, another decorator, and so on).
///
/// ## Filtering
///
/// `DomainFilteredLogger` drops a message without forwarding it and
/// without evaluating its `message` closure when either of the following
/// is true:
///
/// - `level == .disabled`
/// - the severity of `level` is below the effective threshold for
///   `domain`. The effective threshold is
///   ``domainMinimumLevels``\[`domain`\] when present, otherwise
///   ``defaultMinimumLevel``.
public struct DomainFilteredLogger: Logger {
    /// A severity threshold for ``DomainFilteredLogger``.
    ///
    /// `MinimumLevel` is intentionally severity-only and does not include a
    /// `disabled` case: per the `LoggerLevel` contract, `disabled` is a
    /// per-message sentinel and must not be used as a threshold value.
    /// To turn off logging entirely, use a logger that drops every message
    /// instead of configuring a threshold.
    public enum MinimumLevel: CaseIterable, Sendable {
        /// The most detailed severity, intended for fine-grained tracing.
        case verbose

        /// A detailed severity intended for debugging.
        case debug

        /// An informational severity describing normal operation.
        case info

        /// A severity for potential issues that do not yet stop execution.
        case warning

        /// A severity for error conditions that require attention.
        case error

        /// The default minimum severity used when none is specified.
        ///
        /// Equal to ``MinimumLevel/warning``.
        public static let defaultLevel = MinimumLevel.warning
    }

    /// The minimum severity applied to any domain that is not listed in
    /// ``domainMinimumLevels``.
    public let defaultMinimumLevel: MinimumLevel

    /// Per-domain minimum severities. A domain whose key is absent from
    /// this dictionary uses ``defaultMinimumLevel``.
    public let domainMinimumLevels: [LoggerDomain: MinimumLevel]

    private let upstream: any Logger

    /// Creates a `DomainFilteredLogger`.
    ///
    /// - Parameters:
    ///   - upstream: The `Logger` that receives messages that pass the
    ///     threshold check.
    ///   - defaultMinimumLevel: The minimum severity applied to any
    ///     domain not present in `domainMinimumLevels`. Defaults to
    ///     ``MinimumLevel/defaultLevel``.
    ///   - domainMinimumLevels: Per-domain minimum severities. A domain
    ///     whose key is absent uses `defaultMinimumLevel`. Defaults to
    ///     an empty dictionary.
    public init(
        upstream: any Logger,
        defaultMinimumLevel: MinimumLevel = .defaultLevel,
        domainMinimumLevels: [LoggerDomain: MinimumLevel] = [:]
    ) {
        self.upstream = upstream
        self.defaultMinimumLevel = defaultMinimumLevel
        self.domainMinimumLevels = domainMinimumLevels
    }

    public func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        guard level != .disabled else { return }
        let threshold = domainMinimumLevels[domain] ?? defaultMinimumLevel
        guard level >= threshold.asLoggerLevel else { return }
        upstream.log(level, domain, message())
    }
}

extension DomainFilteredLogger.MinimumLevel {
    fileprivate var asLoggerLevel: LoggerLevel {
        switch self {
        case .verbose: return .verbose
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
}
