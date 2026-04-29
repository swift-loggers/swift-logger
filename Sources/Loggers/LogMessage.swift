/// A structured log message composed of one or more ``LogSegment`` values
/// with independent privacy annotations.
///
/// `LogMessage` is the payload form delivered to a ``Logger``. It is the
/// destination type of string-literal and string-interpolation expressions
/// at log call sites:
///
///     logger.info(.auth, "User \(name, privacy: .private) signed in")
///
/// A literal with no interpolations becomes a single ``LogPrivacy/public``
/// segment. An interpolation without an explicit privacy label also
/// defaults to ``LogPrivacy/public``; this matches the ergonomics of
/// `os_log`'s `%{public}s` convention. Call sites that include
/// personally identifiable information must annotate the interpolation
/// explicitly with `privacy: .private` or `privacy: .sensitive`.
///
/// Non-privacy-native sinks render messages through
/// ``redactedDescription``, which substitutes private and sensitive
/// segments with the literal strings `<private>` and `<redacted>`
/// respectively.
public struct LogMessage:
    Sendable,
    Codable,
    Equatable,
    ExpressibleByStringLiteral,
    ExpressibleByStringInterpolation {
    /// The ordered segments that make up this message.
    public var segments: [LogSegment]

    /// Creates a message from an explicit list of segments.
    ///
    /// - Parameter segments: The ordered segments that compose the
    ///   message.
    public init(segments: [LogSegment]) {
        self.segments = segments
    }

    /// Creates a message containing a single ``LogPrivacy/public``
    /// segment with the given text.
    ///
    /// - Parameter value: The segment text.
    public init(stringLiteral value: String) {
        segments = value.isEmpty
            ? []
            : [LogSegment(value, privacy: .public)]
    }

    /// Creates a message from a Swift string interpolation expression.
    ///
    /// - Parameter stringInterpolation: The interpolation accumulator
    ///   produced by the Swift compiler.
    public init(stringInterpolation: StringInterpolation) {
        segments = stringInterpolation.segments
    }

    /// Accumulates the literal and interpolated parts of a
    /// ``LogMessage`` produced by a Swift string interpolation
    /// expression.
    ///
    /// Adjacent segments that share the same privacy annotation are
    /// coalesced into a single segment so downstream rendering does not
    /// reintroduce fragmentation that the call site did not intend.
    public struct StringInterpolation: StringInterpolationProtocol {
        @usableFromInline
        var segments: [LogSegment]

        /// Creates the accumulator with empty state.
        ///
        /// - Parameters:
        ///   - literalCapacity: Total length of the literal portions.
        ///     Used as a heuristic only; the implementation does not
        ///     pre-allocate based on it.
        ///   - interpolationCount: Number of interpolated values.
        public init(literalCapacity _: Int, interpolationCount _: Int) {
            segments = []
        }

        /// Appends a literal portion of the interpolation as a
        /// ``LogPrivacy/public`` segment.
        ///
        /// - Parameter literal: The literal text.
        public mutating func appendLiteral(_ literal: String) {
            guard !literal.isEmpty else { return }
            append(literal, privacy: .public)
        }

        /// Appends an interpolated value as a segment with the given
        /// privacy annotation.
        ///
        /// - Parameters:
        ///   - value: The interpolated value. Rendered with
        ///     `String(describing:)`.
        ///   - privacy: The privacy annotation. Defaults to
        ///     ``LogPrivacy/public``.
        public mutating func appendInterpolation<T>(
            _ value: T,
            privacy: LogPrivacy = .public
        ) {
            append(String(describing: value), privacy: privacy)
        }

        private mutating func append(_ text: String, privacy: LogPrivacy) {
            if let last = segments.last, last.privacy == privacy {
                segments[segments.count - 1].value += text
            } else {
                segments.append(LogSegment(text, privacy: privacy))
            }
        }
    }
}

extension LogMessage {
    /// A textual rendering suitable for non-privacy-native sinks.
    ///
    /// Each segment is rendered according to its privacy annotation:
    ///
    /// - ``LogPrivacy/public``    -- segment value verbatim.
    /// - ``LogPrivacy/private``   -- the literal string `<private>`.
    /// - ``LogPrivacy/sensitive`` -- the literal string `<redacted>`.
    ///
    /// Privacy-native sinks (for example an OSLog adapter) may map
    /// segments onto a backend-specific privacy primitive instead of
    /// using this rendering.
    public var redactedDescription: String {
        var result = ""
        for segment in segments {
            switch segment.privacy {
            case .public:
                result.append(segment.value)
            case .private:
                result.append("<private>")
            case .sensitive:
                result.append("<redacted>")
            }
        }
        return result
    }
}
