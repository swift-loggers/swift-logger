import Foundation

/// A typed value carried by a ``LogAttribute``.
///
/// `LogValue` covers the primitive shapes needed by structured logging
/// without committing to a vendor-specific schema. Remote adapters
/// (Elasticsearch, Datadog, Splunk, Loki) own their own encoders and map
/// `LogValue` onto each backend's native field, label, and tag model.
///
/// > Important: The synthesized `Codable` conformance produces a
/// > debug-friendly JSON shape. It is intentionally **not** a universal
/// > vendor schema. A remote adapter must not rely on the default
/// > `Codable` output for over-the-wire encoding.
public enum LogValue: Sendable, Codable, Equatable {
    /// A textual value.
    case string(String)

    /// A signed 64-bit integer value.
    case integer(Int64)

    /// A double-precision floating-point value.
    case double(Double)

    /// A boolean value.
    case bool(Bool)

    /// A timestamp value. The encoded form depends on the encoder's
    /// date strategy; remote adapters typically override this.
    case date(Date)

    /// An ordered sequence of values.
    indirect case array([LogValue])

    /// A keyed collection of values.
    indirect case object([String: LogValue])

    /// The absence of a value.
    case null
}

extension LogValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension LogValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }
}

extension LogValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension LogValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension LogValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: LogValue...) {
        self = .array(elements)
    }
}

extension LogValue: ExpressibleByDictionaryLiteral {
    /// Creates an object value from a dictionary literal.
    ///
    /// When the literal contains duplicate keys, the value associated
    /// with the last occurrence wins. This matches the convention of
    /// `Dictionary(_:uniquingKeysWith:)` and avoids a runtime trap on
    /// a public `ExpressibleByDictionaryLiteral` initializer.
    public init(dictionaryLiteral elements: (String, LogValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, new in new }))
    }
}

extension LogValue: ExpressibleByNilLiteral {
    public init(nilLiteral _: ()) {
        self = .null
    }
}
