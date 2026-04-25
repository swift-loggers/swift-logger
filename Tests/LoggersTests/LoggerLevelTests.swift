import Loggers
import Testing

@Suite("LoggerLevel")
struct LoggerLevelTests {
    @Test("Raw values are case names")
    func rawValuesAreCaseNames() {
        #expect(LoggerLevel.disabled.rawValue == "disabled")
        #expect(LoggerLevel.verbose.rawValue == "verbose")
        #expect(LoggerLevel.debug.rawValue == "debug")
        #expect(LoggerLevel.info.rawValue == "info")
        #expect(LoggerLevel.warning.rawValue == "warning")
        #expect(LoggerLevel.error.rawValue == "error")
    }

    @Test("Severities are Comparable in increasing severity order")
    func severitiesAreComparable() {
        #expect(LoggerLevel.verbose < .debug)
        #expect(LoggerLevel.debug < .info)
        #expect(LoggerLevel.info < .warning)
        #expect(LoggerLevel.warning < .error)
        #expect(LoggerLevel.error > .warning)
        #expect(LoggerLevel.info == .info)
    }

    @Test("Disabled sentinel sorts below every severity")
    func disabledSortsBelowSeverities() {
        #expect(LoggerLevel.disabled < .verbose)
        #expect(LoggerLevel.disabled < .debug)
        #expect(LoggerLevel.disabled < .info)
        #expect(LoggerLevel.disabled < .warning)
        #expect(LoggerLevel.disabled < .error)
    }

    @Test("Description returns the case name")
    func description() {
        #expect(LoggerLevel.disabled.description == "disabled")
        #expect(LoggerLevel.verbose.description == "verbose")
        #expect(LoggerLevel.debug.description == "debug")
        #expect(LoggerLevel.info.description == "info")
        #expect(LoggerLevel.warning.description == "warning")
        #expect(LoggerLevel.error.description == "error")
    }

    @Test("Default level is warning")
    func defaultLevel() {
        #expect(LoggerLevel.defaultLevel == .warning)
    }

    @Test("allCases is in declaration order")
    func allCasesOrder() {
        #expect(LoggerLevel.allCases == [
            .disabled, .verbose, .debug, .info, .warning, .error
        ])
    }
}
