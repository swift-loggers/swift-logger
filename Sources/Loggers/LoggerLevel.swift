/// A log level tag attached to log messages, plus a sentinel for messages
/// that should be suppressed unconditionally.
///
/// `LoggerLevel` carries two distinct kinds of values:
///
/// - The five severity levels ``verbose``, ``debug``, ``info``,
///   ``warning``, and ``error``, ordered from least to most severe. These
///   form a threshold lattice and are the only values produced by the
///   convenience methods on ``Logger``.
/// - The non-severity sentinel ``disabled``, which marks a message as
///   skippable regardless of threshold. The convenience methods on
///   ``Logger`` never emit ``disabled``; it can only be passed by
///   calling ``Logger/log(_:_:_:)`` directly.
///
/// `Comparable` orders only the five severities meaningfully. ``disabled``
/// participates in the order so the type can be totally sorted, but the
/// order is a representation detail; treating ``disabled`` as a threshold
/// contradicts its meaning. Implementations of ``Logger`` must drop a
/// message tagged ``disabled`` and must not evaluate its `message`
/// closure. A typical threshold-aware implementation:
///
///     guard threshold != .disabled, level != .disabled, level >= threshold else { return }
///
/// To turn off logging entirely, use a logger that drops every message
/// rather than setting a threshold.
///
/// The raw value of each case is its case name (`"disabled"`, `"verbose"`,
/// and so on). This is part of the public contract and is suitable for
/// JSON or log file serialization.
public enum LoggerLevel: String, CaseIterable, Sendable {
    /// A sentinel marking a message as suppressible regardless of threshold.
    ///
    /// Implementations of ``Logger`` must drop a message tagged with this
    /// case and must not evaluate its `message` closure. It is not a
    /// severity level and must not be used as a threshold value.
    case disabled

    /// The most detailed severity, intended for fine-grained tracing.
    case verbose

    /// A detailed message intended for debugging.
    case debug

    /// An informational message describing normal operation.
    case info

    /// A warning about a potential issue that does not yet stop execution.
    case warning

    /// A message describing an error condition that requires attention.
    case error

    /// The default severity used when none is specified.
    ///
    /// Equal to ``LoggerLevel/warning``.
    public static let defaultLevel = LoggerLevel.warning
}

extension LoggerLevel: CustomStringConvertible {
    /// A textual representation of the level, equal to `rawValue`.
    @inlinable
    public var description: String {
        rawValue
    }
}

extension LoggerLevel: Comparable {
    /// Compares two levels by sort order.
    ///
    /// Among the five severities ``verbose`` through ``error``, the order
    /// is by increasing severity. ``disabled`` is not a severity; it sorts
    /// below every severity as a representation detail so the type can be
    /// totally ordered, and must not be used as a threshold.
    ///
    /// - Parameters:
    ///   - lhs: The first level to compare.
    ///   - rhs: The second level to compare.
    /// - Returns: `true` if `lhs` sorts before `rhs`. When both operands
    ///   are severities, this is equivalent to `lhs` being less severe
    ///   than `rhs`. When either operand is ``disabled``, the result
    ///   reflects sort order only.
    public static func < (lhs: LoggerLevel, rhs: LoggerLevel) -> Bool {
        lhs.sortRank < rhs.sortRank
    }

    private var sortRank: Int {
        switch self {
        case .disabled: return 0
        case .verbose: return 1
        case .debug: return 2
        case .info: return 3
        case .warning: return 4
        case .error: return 5
        }
    }
}
