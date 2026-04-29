import Foundation

/// A keyed value attached to a log entry, with its own privacy
/// annotation.
///
/// Attributes carry structured metadata alongside a ``LogMessage``:
/// request identifiers, user identifiers, durations, status codes, and
/// the like. Privacy on an attribute defaults to ``LogPrivacy/public``;
/// call sites that include personally identifiable information must
/// annotate the attribute explicitly.
///
/// Non-privacy-native sinks render attributes through
/// ``redactedDescription``, which substitutes private and sensitive
/// values with the literal strings `<private>` and `<redacted>`
/// respectively.
public struct LogAttribute: Sendable, Codable, Equatable {
    /// The attribute key.
    public var key: String

    /// The attribute value.
    public var value: LogValue

    /// The privacy annotation applied to ``value`` by non-privacy-native
    /// sinks.
    public var privacy: LogPrivacy

    /// Creates an attribute.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - value: The attribute value.
    ///   - privacy: The privacy annotation. Defaults to
    ///     ``LogPrivacy/public``.
    public init(_ key: String, _ value: LogValue, privacy: LogPrivacy = .public) {
        self.key = key
        self.value = value
        self.privacy = privacy
    }

    /// Creates an attribute with labeled key and value.
    ///
    /// Equivalent to the primary positional initializer; provided for
    /// call sites that benefit from explicit argument labels.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - value: The attribute value.
    ///   - privacy: The privacy annotation. Defaults to
    ///     ``LogPrivacy/public``.
    public init(key: String, value: LogValue, privacy: LogPrivacy = .public) {
        self.key = key
        self.value = value
        self.privacy = privacy
    }
}

// MARK: - Convenience initializers for common Swift types

//
// Thin wrappers over the `LogValue` initializer that let call sites
// pass a runtime `String`, `Bool`, integer, floating-point, or `Date`
// directly:
//
//     LogAttribute("auth.success", success)
//     LogAttribute("auth.username", username, privacy: .private)
//
// Literals continue to resolve through the primary `LogValue`
// initializer via the `ExpressibleBy*Literal` conformances on
// `LogValue`, so these overloads are additive and do not change
// existing call sites.

extension LogAttribute {
    /// Creates an attribute carrying a `String` value.
    public init(_ key: String, _ value: String, privacy: LogPrivacy = .public) {
        self.init(key, .string(value), privacy: privacy)
    }

    /// Creates an attribute carrying a `Bool` value.
    public init(_ key: String, _ value: Bool, privacy: LogPrivacy = .public) {
        self.init(key, .bool(value), privacy: privacy)
    }

    /// Creates an attribute carrying any binary integer value.
    ///
    /// Out-of-range values are clamped to `Int64.min` / `Int64.max` so
    /// logging never traps on, for example, a `UInt64` greater than
    /// `Int64.max`.
    public init<I: BinaryInteger>(
        _ key: String,
        _ value: I,
        privacy: LogPrivacy = .public
    ) {
        self.init(key, .integer(Int64(clamping: value)), privacy: privacy)
    }

    /// Creates an attribute carrying any binary floating-point value.
    public init<F: BinaryFloatingPoint>(
        _ key: String,
        _ value: F,
        privacy: LogPrivacy = .public
    ) {
        self.init(key, .double(Double(value)), privacy: privacy)
    }

    /// Creates an attribute carrying a `Date` value.
    public init(_ key: String, _ value: Date, privacy: LogPrivacy = .public) {
        self.init(key, .date(value), privacy: privacy)
    }
}

extension LogAttribute {
    /// A textual rendering of the attribute suitable for
    /// non-privacy-native sinks.
    ///
    /// The output has the shape `key=<value-or-redacted>` where the
    /// value side honors the privacy annotation:
    ///
    /// - ``LogPrivacy/public``    -- `key=<value>`.
    /// - ``LogPrivacy/private``   -- `key=<private>`.
    /// - ``LogPrivacy/sensitive`` -- `key=<redacted>`.
    public var redactedDescription: String {
        switch privacy {
        case .public:
            return "\(key)=\(value.compactDescription)"
        case .private:
            return "\(key)=<private>"
        case .sensitive:
            return "\(key)=<redacted>"
        }
    }
}

extension LogValue {
    /// A compact textual rendering used by ``LogAttribute/redactedDescription``.
    ///
    /// This is intentionally minimal and is **not** a vendor encoding.
    /// Remote adapters must not rely on this format.
    var compactDescription: String {
        switch self {
        case let .string(value): return value
        case let .integer(value): return String(value)
        case let .double(value): return String(value)
        case let .bool(value): return value ? "true" : "false"
        case let .date(value): return String(describing: value)
        case let .array(values):
            return "[" + values.map(\.compactDescription).joined(separator: ", ") + "]"
        case let .object(dict):
            let pairs = dict
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value.compactDescription)" }
            return "{" + pairs.joined(separator: ", ") + "}"
        case .null: return "null"
        }
    }
}
