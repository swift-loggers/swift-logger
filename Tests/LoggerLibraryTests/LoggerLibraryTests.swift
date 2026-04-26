import LoggerLibrary
import Testing

@Suite("LoggerLibrary umbrella")
struct LoggerLibraryTests {
    @Test("Logger protocol re-exported from Loggers")
    func loggerProtocolReExported() {
        let logger: any Logger = NoOpLogger()
        logger.info("Domain", "msg")
    }

    @Test("LoggerLevel re-exported from Loggers")
    func loggerLevelReExported() {
        let level: LoggerLevel = .info
        #expect(level == .info)
    }

    @Test("LoggerDomain re-exported from Loggers")
    func loggerDomainReExported() {
        let domain: LoggerDomain = "Network"
        #expect(domain.rawValue == "Network")
    }

    @Test("PrintLogger re-exported from LoggerPrint")
    func printLoggerReExported() {
        let logger = PrintLogger(minimumLevel: .error, sink: { _ in })
        logger.info("Domain", "msg")
    }

    @Test("DomainFilteredLogger re-exported from LoggerFiltering")
    func domainFilteredLoggerReExported() {
        let logger = DomainFilteredLogger(
            upstream: NoOpLogger(),
            defaultMinimumLevel: .info,
            domainMinimumLevels: [:]
        )
        logger.info("Domain", "msg")
    }

    @Test("NoOpLogger re-exported from LoggerNoOp")
    func noOpLoggerReExported() {
        let logger = NoOpLogger()
        logger.info("Domain", "msg")
    }
}
