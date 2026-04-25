/// A type that emits log messages tagged with a log level and a domain.
///
/// Adopt `Logger` in libraries and modules that need to produce log messages
/// without binding to a concrete logging backend. The application layer
/// supplies the actual implementation and injects it as `any Logger`,
/// keeping individual modules free of logging policy.
///
/// Conforming types must implement ``log(_:_:_:)``. The convenience
/// methods ``verbose(_:_:)``, ``debug(_:_:)``, ``info(_:_:)``,
/// ``warning(_:_:)`` and ``error(_:_:)`` forward to it with a fixed level
/// and do not need to be reimplemented.
///
/// The message parameter is an `@autoclosure`, so a logger that suppresses
/// a message, for example because its level is below a threshold, never
/// pays the cost of building the string. Callers may include arbitrarily
/// complex string-building work without conditional guards:
///
///     logger.debug("Network", "Headers: \(formatHeaders(request))")
///
/// `Logger` refines `Sendable`, so a value can be passed across isolation
/// boundaries. Conforming types are responsible for serializing any
/// internal mutable state.
public protocol Logger: Sendable {
    /// Emits a single log message.
    ///
    /// Implementations decide whether to render, drop, or buffer the
    /// message based on `level`, `domain`, and any internal state. The
    /// `message` closure is evaluated only by implementations that
    /// actually use it, so callers can include arbitrarily complex
    /// string-building work without conditional guards.
    ///
    /// - Parameters:
    ///   - level: The severity of the message, or
    ///     ``LoggerLevel/disabled`` to mark the message as skippable.
    ///     Implementations must drop the message and must not evaluate
    ///     the `message` closure when `level == .disabled`.
    ///   - domain: The subsystem the message belongs to. Useful for
    ///     routing and per-domain filtering.
    ///   - message: An autoclosure that produces the message string. The
    ///     closure is `@escaping @Sendable`, so an implementation may
    ///     evaluate it after this call returns and across isolation
    ///     boundaries; captures must therefore be `Sendable`.
    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    )
}

extension Logger {
    /// Emits a message at the ``LoggerLevel/verbose`` level.
    ///
    /// - Parameters:
    ///   - domain: The subsystem the message belongs to.
    ///   - message: An autoclosure that produces the message string.
    @inlinable
    public func verbose(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        log(.verbose, domain, message())
    }

    /// Emits a message at the ``LoggerLevel/debug`` level.
    ///
    /// - Parameters:
    ///   - domain: The subsystem the message belongs to.
    ///   - message: An autoclosure that produces the message string.
    @inlinable
    public func debug(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        log(.debug, domain, message())
    }

    /// Emits a message at the ``LoggerLevel/info`` level.
    ///
    /// - Parameters:
    ///   - domain: The subsystem the message belongs to.
    ///   - message: An autoclosure that produces the message string.
    @inlinable
    public func info(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        log(.info, domain, message())
    }

    /// Emits a message at the ``LoggerLevel/warning`` level.
    ///
    /// - Parameters:
    ///   - domain: The subsystem the message belongs to.
    ///   - message: An autoclosure that produces the message string.
    @inlinable
    public func warning(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        log(.warning, domain, message())
    }

    /// Emits a message at the ``LoggerLevel/error`` level.
    ///
    /// - Parameters:
    ///   - domain: The subsystem the message belongs to.
    ///   - message: An autoclosure that produces the message string.
    @inlinable
    public func error(
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        log(.error, domain, message())
    }
}
