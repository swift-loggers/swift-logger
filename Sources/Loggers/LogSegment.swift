/// A contiguous piece of a structured log message with an independent
/// privacy annotation.
///
/// Segments compose into a ``LogMessage`` and are typically produced by
/// string interpolation:
///
///     let message: LogMessage = "User \(name, privacy: .private) signed in"
///
/// Privacy on a segment defaults to ``LogPrivacy/public``. Call sites
/// that include private or sensitive data must annotate it explicitly.
public struct LogSegment: Sendable, Codable, Equatable {
    /// The segment text. Always a plain `String`; segments do not nest.
    public var value: String

    /// The privacy annotation applied to ``value`` by non-privacy-native
    /// sinks.
    public var privacy: LogPrivacy

    /// Creates a segment.
    ///
    /// - Parameters:
    ///   - value: The segment text.
    ///   - privacy: The privacy annotation applied to `value`. Defaults
    ///     to ``LogPrivacy/public``.
    public init(_ value: String, privacy: LogPrivacy = .public) {
        self.value = value
        self.privacy = privacy
    }
}
