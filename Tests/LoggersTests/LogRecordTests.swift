import Foundation
import Loggers
import Testing

@Suite("LogRecord")
struct LogRecordTests {
    @Test("Public init stores all fields")
    func publicInitStoresAllFields() {
        let timestamp = Date(timeIntervalSince1970: 1_234_567_890)
        let attributes: [LogAttribute] = [
            LogAttribute("http.route", "/v1/users"),
            LogAttribute("http.status_code", 200)
        ]
        let message: LogMessage = "request started"

        let record = LogRecord(
            timestamp: timestamp,
            level: .info,
            domain: "Network",
            message: message,
            attributes: attributes
        )

        #expect(record.timestamp == timestamp)
        #expect(record.level == .info)
        #expect(record.domain == "Network")
        #expect(record.message == message)
        #expect(record.attributes == attributes)
    }

    @Test("Public init preserves empty attributes")
    func publicInitPreservesEmptyAttributes() {
        let record = LogRecord(
            timestamp: Date(timeIntervalSince1970: 0),
            level: .warning,
            domain: "D",
            message: "m",
            attributes: []
        )
        #expect(record.attributes.isEmpty)
    }

    @Test("Records with the same payload are Equatable")
    func equatable() {
        let timestamp = Date(timeIntervalSince1970: 0)
        let lhs = LogRecord(
            timestamp: timestamp,
            level: .error,
            domain: "D",
            message: "m",
            attributes: [LogAttribute("k", "v")]
        )
        let rhs = LogRecord(
            timestamp: timestamp,
            level: .error,
            domain: "D",
            message: "m",
            attributes: [LogAttribute("k", "v")]
        )
        #expect(lhs == rhs)
    }
}
