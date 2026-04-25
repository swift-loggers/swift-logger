import Loggers
import Testing

@Suite("LoggerDomain")
struct LoggerDomainTests {
    @Test("String literal initializer")
    func stringLiteralInitialization() {
        let domain: LoggerDomain = "Network"
        #expect(domain.rawValue == "Network")
        #expect(domain.description == "Network")
    }

    @Test("Explicit initializer matches string literal")
    func explicitInitialization() {
        let viaInit = LoggerDomain("Test")
        let viaLiteral: LoggerDomain = "Test"
        #expect(viaInit == viaLiteral)
        #expect(viaInit.rawValue == "Test")
    }

    @Test("RawRepresentable initializer")
    func rawValueInitializer() {
        let domain = LoggerDomain(rawValue: "Auth")
        #expect(domain.rawValue == "Auth")
        #expect(domain.description == "Auth")
    }

    @Test("Positional initializer stores the identifier")
    func positionalInitializer() {
        let identifier = String("Custom")
        let domain = LoggerDomain(identifier)
        #expect(domain.rawValue == "Custom")
        #expect(domain.description == "Custom")
    }

    @Test("Description equals rawValue")
    func descriptionMirrorsRawValue() {
        let domain = LoggerDomain("Storage")
        #expect(domain.description == domain.rawValue)
    }

    @Test("Equality")
    func equality() {
        let network: LoggerDomain = "Network"
        let networkCopy: LoggerDomain = "Network"
        let database: LoggerDomain = "Database"
        #expect(network == networkCopy)
        #expect(network != database)
    }

    @Test("Equal values produce equal hash values")
    func hashable() {
        let network: LoggerDomain = "Network"
        let networkCopy: LoggerDomain = "Network"
        #expect(network.hashValue == networkCopy.hashValue)
    }

    @Test("Usable as Dictionary key")
    func dictionaryKey() {
        var levels: [LoggerDomain: LoggerLevel] = [:]
        let network: LoggerDomain = "Network"
        let database: LoggerDomain = "Database"
        levels[network] = .debug
        levels[database] = .info
        #expect(levels[network] == .debug)
        #expect(levels[database] == .info)
        #expect(levels.count == 2)
    }

    @Test("Usable in Set")
    func setUsage() {
        var domains: Set<LoggerDomain> = []
        domains.insert("Network")
        domains.insert("Database")
        domains.insert("Network")
        #expect(domains.count == 2)
        #expect(domains.contains("Network"))
        #expect(domains.contains("Database"))
    }

    @Test("String interpolation yields rawValue")
    func stringInterpolation() {
        let domain: LoggerDomain = "Network"
        #expect("\(domain)" == "Network")
    }
}
