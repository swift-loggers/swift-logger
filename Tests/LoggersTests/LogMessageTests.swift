import Loggers
import Testing

@Suite("LogMessage")
struct LogMessageTests {
    @Test("Plain string literal becomes a single public segment")
    func stringLiteralBecomesPublicSegment() {
        let message: LogMessage = "hello"
        #expect(message == LogMessage(segments: [LogSegment("hello", privacy: .public)]))
        #expect(message.redactedDescription == "hello")
    }

    @Test("Public interpolation is rendered verbatim")
    func publicInterpolationVerbatim() {
        let name = "Alice"
        let message: LogMessage = "Hello \(name)"
        #expect(message.redactedDescription == "Hello Alice")
    }

    @Test("Private interpolation is rendered as <private>")
    func privateInterpolationRedacted() {
        let name = "Alice"
        let message: LogMessage = "User \(name, privacy: .private) signed in"
        #expect(message.redactedDescription == "User <private> signed in")
    }

    @Test("Sensitive interpolation is rendered as <redacted>")
    func sensitiveInterpolationRedacted() {
        let token = "ey..."
        let message: LogMessage = "Token \(token, privacy: .sensitive)"
        #expect(message.redactedDescription == "Token <redacted>")
    }

    @Test("Adjacent same-privacy segments are coalesced")
    func adjacentSamePrivacySegmentsCoalesce() {
        let value = "x"
        let message: LogMessage = "a\(value)b"
        // All public -- should collapse to a single segment.
        #expect(message.segments.count == 1)
        #expect(message.segments[0].value == "axb")
    }

    @Test("Different-privacy segments are preserved")
    func differentPrivacySegmentsPreserved() {
        let username = "alice"
        let message: LogMessage = "user=\(username, privacy: .private) ok"
        #expect(message.segments.count == 3)
        #expect(message.segments[0] == LogSegment("user=", privacy: .public))
        #expect(message.segments[1] == LogSegment("alice", privacy: .private))
        #expect(message.segments[2] == LogSegment(" ok", privacy: .public))
    }

    @Test("LogMessage(segments:) preserves the explicit segment list")
    func segmentsInitPreservesList() {
        let segments: [LogSegment] = [
            LogSegment("a", privacy: .public),
            LogSegment("b", privacy: .private),
            LogSegment("c", privacy: .sensitive)
        ]
        let message = LogMessage(segments: segments)
        #expect(message.segments == segments)
        #expect(message.redactedDescription == "a<private><redacted>")
    }

    @Test("Empty string literal becomes empty segments")
    func emptyStringLiteral() {
        let message: LogMessage = ""
        #expect(message.segments.isEmpty)
        #expect(message.redactedDescription == "")
    }

    @Test("LogSegment default privacy is .public")
    func logSegmentDefaultPrivacy() {
        let segment = LogSegment("hello")
        #expect(segment.privacy == .public)
        #expect(segment.value == "hello")
    }
}
