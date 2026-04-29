import Loggers
import Testing

@Suite("LogValue")
struct LogValueTests {
    @Test("From string literal")
    func fromStringLiteral() {
        let value: LogValue = "hello"
        #expect(value == .string("hello"))
    }

    @Test("From integer literal")
    func fromIntegerLiteral() {
        let value: LogValue = 42
        #expect(value == .integer(42))
    }

    @Test("From float literal")
    func fromFloatLiteral() {
        let value: LogValue = 3.14
        #expect(value == .double(3.14))
    }

    @Test("From boolean literal")
    func fromBooleanLiteral() {
        let value: LogValue = true
        #expect(value == .bool(true))
    }

    @Test("From nil literal")
    func fromNilLiteral() {
        let value: LogValue = nil
        #expect(value == .null)
    }

    @Test("From array literal")
    func fromArrayLiteral() {
        let value: LogValue = [1, "two", true]
        #expect(value == .array([.integer(1), .string("two"), .bool(true)]))
    }

    @Test("From dictionary literal")
    func fromDictionaryLiteral() {
        let value: LogValue = ["a": 1, "b": "two"]
        #expect(value == .object(["a": .integer(1), "b": .string("two")]))
    }

    @Test("Dictionary literal keeps the last value for duplicate keys")
    func dictionaryLiteralDuplicateKeys() {
        // Intentional duplicates: this test verifies last-wins behavior of
        // the public ExpressibleByDictionaryLiteral initializer, which uses
        // Dictionary(_:uniquingKeysWith:) instead of trapping.
        // swiftlint:disable:next duplicated_key_in_dictionary_literal
        let value: LogValue = ["a": 1, "a": 2, "b": "first", "b": "second"]
        #expect(value == .object(["a": .integer(2), "b": .string("second")]))
    }
}
