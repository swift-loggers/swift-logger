import Foundation
import Loggers
import Testing

@Suite("LogAttribute")
struct LogAttributeTests {
    // MARK: Redaction

    @Test("Public attribute renders key=value")
    func publicAttributeRendering() {
        let attribute = LogAttribute("path", "/v1/users")
        #expect(attribute.redactedDescription == "path=/v1/users")
    }

    @Test("Private attribute renders key=<private>")
    func privateAttributeRendering() {
        let attribute = LogAttribute("user", "alice", privacy: .private)
        #expect(attribute.redactedDescription == "user=<private>")
    }

    @Test("Sensitive attribute renders key=<redacted>")
    func sensitiveAttributeRendering() {
        let attribute = LogAttribute("token", "ey...", privacy: .sensitive)
        #expect(attribute.redactedDescription == "token=<redacted>")
    }

    // MARK: Convenience initializers for runtime values

    @Test("Init with runtime String wraps as .string")
    func stringInit() {
        let username = "alice"
        let attribute = LogAttribute("user", username, privacy: .private)
        #expect(attribute.value == .string("alice"))
        #expect(attribute.privacy == .private)
    }

    @Test("Init with runtime Bool wraps as .bool")
    func boolInit() {
        let success = true
        let attribute = LogAttribute("auth.success", success)
        #expect(attribute.value == .bool(true))
        #expect(attribute.privacy == .public)
    }

    @Test("Init with runtime Int wraps as .integer")
    func integerInit() {
        let count = 42
        let attribute = LogAttribute("count", count)
        #expect(attribute.value == .integer(42))
    }

    @Test("Init with UInt64 above Int64.max clamps")
    func integerClamps() {
        let huge: UInt64 = .max
        let attribute = LogAttribute("count", huge)
        #expect(attribute.value == .integer(.max))
    }

    @Test("Init with runtime Double wraps as .double")
    func doubleInit() {
        let duration = 1.5
        let attribute = LogAttribute("duration", duration)
        #expect(attribute.value == .double(1.5))
    }

    @Test("Init with runtime Float wraps as .double")
    func floatInit() {
        let ratio: Float = 0.5
        let attribute = LogAttribute("ratio", ratio)
        #expect(attribute.value == .double(0.5))
    }

    @Test("Init with Date wraps as .date")
    func dateInit() {
        let timestamp = Date(timeIntervalSince1970: 0)
        let attribute = LogAttribute("timestamp", timestamp)
        #expect(attribute.value == .date(timestamp))
    }

    // MARK: Labeled initializer

    @Test("Labeled init stores key, value, and privacy")
    func labeledInit() {
        let attribute = LogAttribute(
            key: "user",
            value: .string("alice"),
            privacy: .private
        )
        #expect(attribute.key == "user")
        #expect(attribute.value == .string("alice"))
        #expect(attribute.privacy == .private)
    }

    @Test("Labeled init defaults to .public privacy")
    func labeledInitDefaultPrivacy() {
        let attribute = LogAttribute(key: "k", value: .integer(1))
        #expect(attribute.privacy == .public)
    }

    // MARK: LogValue rendering via redactedDescription

    @Test("Renders .null value as null")
    func rendersNull() {
        let attribute = LogAttribute("k", LogValue.null)
        #expect(attribute.redactedDescription == "k=null")
    }

    @Test("Renders .integer value as decimal text")
    func rendersInteger() {
        let attribute = LogAttribute("k", LogValue.integer(-7))
        #expect(attribute.redactedDescription == "k=-7")
    }

    @Test("Renders .double value as decimal text")
    func rendersDouble() {
        let attribute = LogAttribute("k", LogValue.double(1.5))
        #expect(attribute.redactedDescription == "k=1.5")
    }

    @Test("Renders .date value as String(describing:)")
    func rendersDate() {
        let date = Date(timeIntervalSince1970: 0)
        let attribute = LogAttribute("k", LogValue.date(date))
        #expect(attribute.redactedDescription == "k=\(String(describing: date))")
    }

    @Test("Renders .array value as bracketed comma list")
    func rendersArray() {
        let attribute = LogAttribute(
            "tags",
            LogValue.array([.string("sso"), .string("mfa")])
        )
        #expect(attribute.redactedDescription == "tags=[sso, mfa]")
    }

    @Test("Renders .object with keys sorted lexicographically")
    func rendersObjectSorted() {
        let attribute = LogAttribute(
            "labels",
            LogValue.object([
                "z": .integer(1),
                "a": .integer(2),
                "m": .integer(3)
            ])
        )
        #expect(attribute.redactedDescription == "labels={a=2, m=3, z=1}")
    }
}
