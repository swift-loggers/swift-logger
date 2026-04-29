/// A privacy annotation attached to a log segment or attribute value.
///
/// `LogPrivacy` lets call sites mark portions of a log entry as either
/// safe to display verbatim, sensitive enough to be substituted, or
/// fully redacted. Sinks that are not privacy-native (for example
/// `PrintLogger`) honor these annotations through a degradation rule:
///
/// - ``public``    -- render the value verbatim.
/// - ``private``   -- render as the literal string `<private>`.
/// - ``sensitive`` -- render as the literal string `<redacted>`.
///
/// The default at every call site is ``public``. Call sites that handle
/// personally identifiable information must explicitly annotate the
/// affected segment or attribute, mirroring the `os_log` `%{public}s`
/// convention. Defaulting to ``private`` would silently redact
/// development-time messages and was rejected for that reason.
///
/// Privacy-native sinks (for example an OSLog adapter) may map this
/// annotation onto a backend-specific privacy primitive instead of the
/// textual degradation rule.
public enum LogPrivacy: Sendable, Codable, Equatable {
    /// The value is safe to render verbatim.
    case `public`

    /// The value is private and must be redacted by non-privacy-native
    /// sinks. Renders as the literal string `<private>`.
    case `private`

    /// The value is sensitive and must be removed entirely by
    /// non-privacy-native sinks. Renders as the literal string
    /// `<redacted>`.
    case sensitive
}
