import Loggers

/// A `Logger` that drops every message it receives without evaluating the
/// `message` closure.
///
/// `NoOpLogger` is the canonical way to disable logging in a code path:
///
/// - Use it as a placeholder during dependency injection.
/// - Use it in tests to silence log output without changing call sites.
/// - Use it in production paths where logging should be completely off.
///
/// Because the protocol delivers `message` as an `@autoclosure`, the
/// `message` closure is never evaluated when the logger is `NoOpLogger`.
/// The implementation has no stored state and is trivially `Sendable`.
///
/// To turn off logging entirely, prefer `NoOpLogger` over configuring a
/// threshold-based backend with a sentinel value: `LoggerLevel.disabled`
/// is a per-message sentinel, not a valid threshold.
public struct NoOpLogger: Logger {
    /// Creates a new `NoOpLogger`.
    public init() {}

    public func log(
        _: LoggerLevel,
        _: LoggerDomain,
        _: @autoclosure @escaping @Sendable () -> String
    ) {
        // Intentionally empty: no rendering, no sink, no message evaluation.
    }
}
