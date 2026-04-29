/// A type that emits structured log entries tagged with a level, a
/// domain, a message, and optional attributes.
///
/// Adopt `Logger` in libraries and modules that need to produce log
/// entries without binding to a concrete logging backend. The
/// application layer supplies the actual implementation and injects it
/// as `any Logger`, keeping individual modules free of logging policy.
///
/// ## The protocol requirement
///
/// Conforming types must implement
/// ``log(_:_:_:attributes:)``. Both the `message` and `attributes`
/// parameters are `@autoclosure @escaping @Sendable`, so an
/// implementation that drops the entry never pays the cost of building
/// the message or assembling the attribute list:
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
/// `level` and `domain` are passed outside the lazy payload so the
/// drop guard can examine them without evaluating anything.
///
/// ## Convenience overloads
///
/// Call sites use the convenience overloads on this protocol's
/// extension, which accept either a ``LogMessage`` (built directly or
/// via string interpolation) or a `String` (wrapped lazily as
/// `LogMessage("...")`):
///
///     logger.info(.network, "Request started")
///     logger.info(.auth, "User \(name, privacy: .private) signed in")
///     logger.info(.network, "Request started", attributes: [
///         LogAttribute("path", "/v1/users")
///     ])
///
/// ## Sendable
///
/// `Logger` refines `Sendable`, so a value can be passed across
/// isolation boundaries. Conforming types are responsible for
/// serializing any internal mutable state.
public protocol Logger: Sendable {
    /// Emits a single structured log entry.
    ///
    /// Implementations must drop the entry without evaluating
    /// `message` or `attributes` when `level == .disabled`. Threshold-
    /// aware implementations must additionally drop without evaluation
    /// when `level` is below their configured threshold.
    ///
    /// Each of the `message` and `attributes` autoclosures must be
    /// evaluated at most once per entry. The shipped adapters
    /// (`PrintLogger`, `NoOpLogger`, `DomainFilteredLogger`) honor
    /// this; conforming types must do the same.
    ///
    /// - Parameters:
    ///   - level: The severity of the entry, or
    ///     ``LoggerLevel/disabled`` to mark it as skippable.
    ///   - domain: The subsystem the entry belongs to.
    ///   - message: An autoclosure that produces the structured
    ///     message payload. The closure is `@escaping @Sendable`, so
    ///     an implementation may evaluate it after this call returns
    ///     and across isolation boundaries; captures must therefore be
    ///     `Sendable`.
    ///   - attributes: An autoclosure that produces the structured
    ///     attribute list. Same lifetime and isolation rules as
    ///     `message`.
    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute]
    )
}

extension Logger {
    /// Emits a structured log entry with no attributes.
    ///
    /// Equivalent to ``log(_:_:_:attributes:)`` with an empty
    /// attribute list. The empty-list autoclosure is cheap to evaluate
    /// and is dropped along with `message` when the implementation
    /// drops the entry.
    @inlinable
    public func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage
    ) {
        log(level, domain, message(), attributes: [])
    }

    /// Emits a structured log entry whose message is a plain `String`.
    ///
    /// The `String` is wrapped lazily into a single-segment
    /// ``LogMessage`` with ``LogPrivacy/public`` privacy. The wrap is
    /// performed inside the autoclosure passed to the protocol
    /// requirement, so an implementation that drops the entry never
    /// builds the wrapping `LogMessage`.
    @inlinable
    public func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(
            level,
            domain,
            LogMessage(stringLiteral: message()),
            attributes: attributes()
        )
    }
}

extension Logger {
    /// Emits a structured entry at ``LoggerLevel/verbose``.
    @inlinable
    public func verbose(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(.verbose, domain, message(), attributes: attributes())
    }

    /// Emits a structured entry at ``LoggerLevel/debug``.
    @inlinable
    public func debug(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(.debug, domain, message(), attributes: attributes())
    }

    /// Emits a structured entry at ``LoggerLevel/info``.
    @inlinable
    public func info(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(.info, domain, message(), attributes: attributes())
    }

    /// Emits a structured entry at ``LoggerLevel/warning``.
    @inlinable
    public func warning(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(.warning, domain, message(), attributes: attributes())
    }

    /// Emits a structured entry at ``LoggerLevel/error``.
    @inlinable
    public func error(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(.error, domain, message(), attributes: attributes())
    }
}

extension Logger {
    /// Emits a `String` entry at ``LoggerLevel/verbose``.
    @inlinable
    public func verbose(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(
            .verbose,
            domain,
            LogMessage(stringLiteral: message()),
            attributes: attributes()
        )
    }

    /// Emits a `String` entry at ``LoggerLevel/debug``.
    @inlinable
    public func debug(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(
            .debug,
            domain,
            LogMessage(stringLiteral: message()),
            attributes: attributes()
        )
    }

    /// Emits a `String` entry at ``LoggerLevel/info``.
    @inlinable
    public func info(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(
            .info,
            domain,
            LogMessage(stringLiteral: message()),
            attributes: attributes()
        )
    }

    /// Emits a `String` entry at ``LoggerLevel/warning``.
    @inlinable
    public func warning(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(
            .warning,
            domain,
            LogMessage(stringLiteral: message()),
            attributes: attributes()
        )
    }

    /// Emits a `String` entry at ``LoggerLevel/error``.
    @inlinable
    public func error(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute] = []
    ) {
        log(
            .error,
            domain,
            LogMessage(stringLiteral: message()),
            attributes: attributes()
        )
    }
}
