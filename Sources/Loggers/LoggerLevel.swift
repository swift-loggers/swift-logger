/// A log level tag attached to log entries, plus a sentinel for entries
/// that should be suppressed unconditionally.
///
/// `LoggerLevel` is a transport-neutral severity model. Adapters map
/// each value onto their backend's native level set; values that have
/// no exact native counterpart are mapped to the closest neighbor.
///
/// `LoggerLevel` carries two distinct kinds of values:
///
/// - The seven severity levels ``trace``, ``debug``, ``info``,
///   ``notice``, ``warning``, ``error``, and ``critical``, ordered
///   from least to most severe. These form a threshold lattice and
///   are the only values produced by the convenience methods on
///   ``Logger``.
/// - The non-severity sentinel ``disabled``, which marks an entry as
///   skippable regardless of threshold. The convenience methods on
///   ``Logger`` never emit ``disabled``; it can only be passed by
///   calling ``Logger/log(_:_:_:attributes:)`` directly.
///
/// `Comparable` orders only the seven severities meaningfully.
/// ``disabled`` participates in the order so the type can be totally
/// sorted, but the order is a representation detail; treating
/// ``disabled`` as a threshold contradicts its meaning. Implementations
/// of ``Logger`` must drop an entry tagged ``disabled`` and must not
/// evaluate its `message` or `attributes` autoclosures. A typical
/// threshold-aware implementation:
///
///     guard threshold != .disabled, level != .disabled, level >= threshold else { return }
///
/// To turn off logging entirely, use a logger that drops every entry
/// rather than setting a threshold.
///
/// The raw value of each case is its case name (`"disabled"`,
/// `"trace"`, and so on). This is part of the public contract and is
/// suitable for JSON or log file serialization.
public enum LoggerLevel: String, CaseIterable, Codable, Sendable {
    /// A sentinel marking an entry as suppressible regardless of threshold.
    ///
    /// Implementations of ``Logger`` must drop an entry tagged with this
    /// case and must not evaluate its `message` or `attributes`
    /// autoclosures. It is not a severity level and must not be used as
    /// a threshold value.
    case disabled

    /// The most detailed severity, intended for fine-grained tracing.
    case trace

    /// A detailed severity intended for debugging.
    case debug

    /// An informational severity describing normal operation.
    case info

    /// A normal but significant condition worth surfacing above
    /// everyday `info` traffic without rising to a warning.
    case notice

    /// A potential issue that does not yet stop execution.
    case warning

    /// An error condition that requires attention.
    case error

    /// A severe condition that requires immediate attention; typically
    /// an unrecoverable failure or a hard invariant break.
    case critical

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
    /// Among the seven severities ``trace`` through ``critical``, the
    /// order is by increasing severity. ``disabled`` is not a severity;
    /// it sorts below every severity as a representation detail so the
    /// type can be totally ordered, and must not be used as a
    /// threshold.
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
        case .trace: return 1
        case .debug: return 2
        case .info: return 3
        case .notice: return 4
        case .warning: return 5
        case .error: return 6
        case .critical: return 7
        }
    }
}
