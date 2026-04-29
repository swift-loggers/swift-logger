import Foundation

/// A fully materialized log entry, suitable for adapters that need the
/// complete payload (remote sinks, file sinks, structured encoders).
///
/// `LogRecord` is **not** the input form to the ``Logger`` protocol;
/// the protocol takes `level`, `domain`, `message`, and `attributes`
/// separately so that threshold-aware adapters can drop a call without
/// evaluating the lazy payload.
///
/// Adapters that need a record materialize it themselves, after the
/// drop guard:
///
///     guard level != .disabled, level >= minimumLevel else { return }
///     let record = LogRecord(
///         timestamp: dateProvider(),
///         level: level,
///         domain: domain,
///         message: message(),
///         attributes: attributes()
///     )
///
/// The ``timestamp`` is sink-side: it is set by the adapter at the
/// moment it materializes the record, not at the call site. Call sites
/// that need control over the timestamp can wrap their logger in an
/// adapter that does so.
public struct LogRecord: Sendable, Codable, Equatable {
    /// The wall-clock time at which the adapter materialized the
    /// record.
    public var timestamp: Date

    /// The severity of the entry.
    public var level: LoggerLevel

    /// The subsystem the entry belongs to.
    public var domain: LoggerDomain

    /// The structured message payload.
    public var message: LogMessage

    /// The structured attributes attached to the entry.
    public var attributes: [LogAttribute]

    /// Creates a record.
    ///
    /// - Parameters:
    ///   - timestamp: The wall-clock time at which the record is
    ///     materialized.
    ///   - level: The severity of the entry. Adapters should not
    ///     materialize records for ``LoggerLevel/disabled`` calls;
    ///     that sentinel is a per-message drop signal applied before
    ///     the record is built, not a stored severity. The
    ///     initializer does not enforce this at runtime.
    ///   - domain: The subsystem the entry belongs to.
    ///   - message: The structured message payload.
    ///   - attributes: The structured attributes attached to the entry.
    public init(
        timestamp: Date,
        level: LoggerLevel,
        domain: LoggerDomain,
        message: LogMessage,
        attributes: [LogAttribute]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.domain = domain
        self.message = message
        self.attributes = attributes
    }
}
