/// A subsystem identifier attached to log messages.
///
/// A `LoggerDomain` names the part of an application a log message comes
/// from, for example "Network", "Database", or "Authentication". Domains
/// are used by filtering loggers to apply different policies to different
/// subsystems.
///
/// Domains are typically declared once per module as static extensions:
///
///     extension LoggerDomain {
///         static let network: LoggerDomain = "Network"
///         static let database: LoggerDomain = "Database"
///     }
///
/// They can then be used at the call site without repeating the literal:
///
///     logger.info(.network, "Request started")
///
/// Conforming to `ExpressibleByStringLiteral` allows a domain to be
/// created directly from a string at the call site when a static
/// extension is not needed.
public struct LoggerDomain:
    RawRepresentable,
    CustomStringConvertible,
    ExpressibleByStringLiteral,
    Codable,
    Hashable,
    Sendable {
    /// The textual identifier of this domain.
    public let rawValue: String

    /// Creates a domain with the given identifier.
    ///
    /// - Parameter rawValue: The textual identifier.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a domain from a string literal.
    ///
    /// - Parameter value: The textual identifier.
    @inlinable
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// Creates a domain with the given identifier.
    ///
    /// - Parameter rawValue: The textual identifier.
    @inlinable
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// A textual representation of the domain, equal to ``rawValue``.
    @inlinable
    public var description: String {
        rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
