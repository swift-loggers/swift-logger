import Foundation
import Loggers

/// A `Logger` that renders log entries to a textual sink, with a
/// timestamp.
///
/// `PrintLogger` is a default-configured backend suitable for
/// development and scripts. Each emitted line has the shape:
///
///     [<timestamp>] [<level>] [<domain>] <message>
///
/// or, when attributes are present:
///
///     [<timestamp>] [<level>] [<domain>] <message> {key=value, ...}
///
/// The timestamp, sink, and current-time source are pluggable. The
/// default configuration renders an ISO 8601 UTC timestamp with
/// fractional seconds and writes to standard output via `print(_:)`.
///
/// ## Privacy
///
/// `PrintLogger` is not privacy-native. It renders the message and
/// attributes through their `redactedDescription`, which substitutes
/// segments and attribute values according to `LogPrivacy`:
///
/// - `LogPrivacy.public`    -- rendered verbatim.
/// - `LogPrivacy.private`   -- rendered as the literal string
///   `<private>`.
/// - `LogPrivacy.sensitive` -- rendered as the literal string
///   `<redacted>`.
///
/// ## Filtering
///
/// `PrintLogger` drops an entry without evaluating the `dateProvider`,
/// `timestampFormatter`, `message`, `attributes`, or `sink` when
/// either of the following is true:
///
/// - `level == .disabled`
/// - the severity of `level` is below ``minimumLevel``
public struct PrintLogger: Logger {
    /// A severity threshold for ``PrintLogger``.
    ///
    /// `MinimumLevel` is intentionally severity-only and does not
    /// include a `disabled` case: per the `LoggerLevel` contract,
    /// `disabled` is a per-message sentinel and must not be used as a
    /// threshold value. To turn off logging entirely, use a logger
    /// that drops every entry instead of configuring a threshold.
    public enum MinimumLevel: CaseIterable, Sendable {
        /// The most detailed severity, intended for fine-grained
        /// tracing.
        case verbose

        /// A detailed severity intended for debugging.
        case debug

        /// An informational severity describing normal operation.
        case info

        /// A severity for potential issues that do not yet stop
        /// execution.
        case warning

        /// A severity for error conditions that require attention.
        case error

        /// The default minimum severity used when none is specified.
        ///
        /// Equal to ``MinimumLevel/warning``.
        public static let defaultLevel = MinimumLevel.warning
    }

    /// The minimum severity that this logger emits. Entries whose
    /// severity is strictly lower are dropped without evaluating the
    /// message or attributes.
    public let minimumLevel: MinimumLevel

    private let dateProvider: @Sendable () -> Date
    private let timestampFormatter: @Sendable (Date) -> String
    private let sink: @Sendable (String) -> Void

    /// Creates a `PrintLogger` that uses the current wall-clock time,
    /// the default ISO 8601 UTC timestamp formatter, and prints each
    /// line to standard output.
    ///
    /// - Parameter minimumLevel: The minimum severity to emit.
    ///   Defaults to ``MinimumLevel/defaultLevel``.
    public init(minimumLevel: MinimumLevel = .defaultLevel) {
        self.init(
            minimumLevel: minimumLevel,
            dateProvider: { Date() },
            timestampFormatter: PrintLogger.defaultTimestampFormatter,
            sink: { print($0) }
        )
    }

    /// Creates a `PrintLogger` with a custom sink, the current
    /// wall-clock time, and the default ISO 8601 UTC timestamp
    /// formatter.
    ///
    /// - Parameters:
    ///   - minimumLevel: The minimum severity to emit. Defaults to
    ///     ``MinimumLevel/defaultLevel``.
    ///   - sink: Receives each fully formatted log line.
    public init(
        minimumLevel: MinimumLevel = .defaultLevel,
        sink: @escaping @Sendable (String) -> Void
    ) {
        self.init(
            minimumLevel: minimumLevel,
            dateProvider: { Date() },
            timestampFormatter: PrintLogger.defaultTimestampFormatter,
            sink: sink
        )
    }

    /// Creates a `PrintLogger` with full control over time,
    /// formatting, and output destination.
    ///
    /// - Parameters:
    ///   - minimumLevel: The minimum severity to emit. Defaults to
    ///     ``MinimumLevel/defaultLevel``.
    ///   - dateProvider: Returns the timestamp for each emitted line.
    ///     Called only when the entry is not dropped.
    ///   - timestampFormatter: Formats the timestamp returned by
    ///     `dateProvider` into the textual representation included in
    ///     the output line. Called only when the entry is not dropped.
    ///   - sink: Receives each fully formatted log line. Called only
    ///     when the entry is not dropped.
    public init(
        minimumLevel: MinimumLevel = .defaultLevel,
        dateProvider: @escaping @Sendable () -> Date,
        timestampFormatter: @escaping @Sendable (Date) -> String,
        sink: @escaping @Sendable (String) -> Void
    ) {
        self.minimumLevel = minimumLevel
        self.dateProvider = dateProvider
        self.timestampFormatter = timestampFormatter
        self.sink = sink
    }

    public func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute]
    ) {
        guard level != .disabled,
              level >= minimumLevel.asLoggerLevel
        else { return }
        let timestamp = timestampFormatter(dateProvider())
        let messageText = message().redactedDescription
        let resolved = attributes()
        var line = "[\(timestamp)] [\(level)] [\(domain)] \(messageText)"
        if !resolved.isEmpty {
            let rendered = resolved
                .map(\.redactedDescription)
                .joined(separator: ", ")
            line += " {\(rendered)}"
        }
        sink(line)
    }

    /// The default timestamp formatter used by `PrintLogger`.
    ///
    /// Renders the date as an ISO 8601 UTC string with fractional
    /// seconds, for example `2026-04-26T08:30:42.123Z`. The underlying
    /// `ISO8601DateFormatter` is configured once and accessed under an
    /// `NSLock` so the closure can be shared across concurrency
    /// domains without assuming undocumented Foundation thread-safety
    /// guarantees.
    public static let defaultTimestampFormatter: @Sendable (Date) -> String = { date in
        ISO8601FormatterBox.shared.string(from: date)
    }
}

extension PrintLogger.MinimumLevel {
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

private final class ISO8601FormatterBox: @unchecked Sendable {
    static let shared = ISO8601FormatterBox()

    private let lock = NSLock()
    private let formatter: ISO8601DateFormatter

    private init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    func string(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(from: date)
    }
}
