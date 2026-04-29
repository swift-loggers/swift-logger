import Foundation
import Loggers
import Testing

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data)
}

@Suite("Codable round-trip")
struct CodableRoundTripTests {
    // MARK: LoggerDomain

    @Test("LoggerDomain encodes as a single JSON string")
    func loggerDomainEncodesAsString() throws {
        let domain: LoggerDomain = "Network"
        let data = try JSONEncoder().encode(domain)
        let json = String(data: data, encoding: .utf8)
        #expect(json == "\"Network\"")
    }

    @Test("LoggerDomain decodes from a JSON string")
    func loggerDomainDecodesFromString() throws {
        let data = Data("\"Auth\"".utf8)
        let decoded = try JSONDecoder().decode(LoggerDomain.self, from: data)
        #expect(decoded == "Auth")
    }

    @Test("LoggerDomain round-trip")
    func loggerDomainRoundTrip() throws {
        let original: LoggerDomain = "Database"
        #expect(try roundTrip(original) == original)
    }

    // MARK: LoggerLevel

    @Test(
        "LoggerLevel round-trip for every case",
        arguments: LoggerLevel.allCases
    )
    func loggerLevelRoundTrip(level: LoggerLevel) throws {
        #expect(try roundTrip(level) == level)
    }

    // MARK: LogPrivacy

    @Test(
        "LogPrivacy round-trip for every case",
        arguments: [LogPrivacy.public, .private, .sensitive]
    )
    func logPrivacyRoundTrip(privacy: LogPrivacy) throws {
        #expect(try roundTrip(privacy) == privacy)
    }

    // MARK: LogSegment

    @Test("LogSegment round-trip")
    func logSegmentRoundTrip() throws {
        let segment = LogSegment("hello", privacy: .private)
        #expect(try roundTrip(segment) == segment)
    }

    // MARK: LogMessage

    @Test("LogMessage round-trip with single segment")
    func logMessageRoundTripSingleSegment() throws {
        let message: LogMessage = "plain"
        #expect(try roundTrip(message) == message)
    }

    @Test("LogMessage round-trip with mixed-privacy segments")
    func logMessageRoundTripMixedPrivacy() throws {
        let username = "alice"
        let message: LogMessage = "user=\(username, privacy: .private) ok"
        #expect(try roundTrip(message) == message)
    }

    // MARK: LogValue

    @Test(
        "LogValue round-trip for primitive cases",
        arguments: [
            LogValue.string("hello"),
            .integer(42),
            .integer(.min),
            .integer(.max),
            .double(3.14),
            .bool(true),
            .bool(false),
            .null
        ]
    )
    func logValuePrimitiveRoundTrip(value: LogValue) throws {
        #expect(try roundTrip(value) == value)
    }

    @Test("LogValue round-trip for nested array and object")
    func logValueNestedRoundTrip() throws {
        let value: LogValue = .object([
            "tags": .array([.string("sso"), .string("mfa")]),
            "count": .integer(2),
            "nested": .object(["flag": .bool(true)])
        ])
        #expect(try roundTrip(value) == value)
    }

    // MARK: LogAttribute

    @Test("LogAttribute round-trip")
    func logAttributeRoundTrip() throws {
        let attribute = LogAttribute("user", "alice", privacy: .private)
        #expect(try roundTrip(attribute) == attribute)
    }

    // MARK: LogRecord

    @Test("LogRecord round-trip")
    func logRecordRoundTrip() throws {
        let record = LogRecord(
            timestamp: Date(timeIntervalSince1970: 1_234_567_890),
            level: .warning,
            domain: "Network",
            message: "request \("alice", privacy: .private)",
            attributes: [
                LogAttribute("http.route", "/v1/users"),
                LogAttribute("http.status_code", 200),
                LogAttribute("auth.username", "alice", privacy: .private)
            ]
        )
        #expect(try roundTrip(record) == record)
    }
}
