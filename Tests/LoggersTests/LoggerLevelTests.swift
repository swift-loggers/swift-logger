import Loggers
import Testing

@Suite("LoggerLevel")
struct LoggerLevelTests {
    @Test("Raw values are case names")
    func rawValuesAreCaseNames() {
        #expect(LoggerLevel.disabled.rawValue == "disabled")
        #expect(LoggerLevel.trace.rawValue == "trace")
        #expect(LoggerLevel.debug.rawValue == "debug")
        #expect(LoggerLevel.info.rawValue == "info")
        #expect(LoggerLevel.notice.rawValue == "notice")
        #expect(LoggerLevel.warning.rawValue == "warning")
        #expect(LoggerLevel.error.rawValue == "error")
        #expect(LoggerLevel.critical.rawValue == "critical")
    }

    @Test("Severities are Comparable in increasing severity order")
    func severitiesAreComparable() {
        #expect(LoggerLevel.trace < .debug)
        #expect(LoggerLevel.debug < .info)
        #expect(LoggerLevel.info < .notice)
        #expect(LoggerLevel.notice < .warning)
        #expect(LoggerLevel.warning < .error)
        #expect(LoggerLevel.error < .critical)
        #expect(LoggerLevel.critical > .warning)
        #expect(LoggerLevel.info == .info)
    }

    @Test("Disabled sentinel sorts below every severity")
    func disabledSortsBelowSeverities() {
        #expect(LoggerLevel.disabled < .trace)
        #expect(LoggerLevel.disabled < .debug)
        #expect(LoggerLevel.disabled < .info)
        #expect(LoggerLevel.disabled < .notice)
        #expect(LoggerLevel.disabled < .warning)
        #expect(LoggerLevel.disabled < .error)
        #expect(LoggerLevel.disabled < .critical)
    }

    @Test("Description returns the case name")
    func description() {
        #expect(LoggerLevel.disabled.description == "disabled")
        #expect(LoggerLevel.trace.description == "trace")
        #expect(LoggerLevel.debug.description == "debug")
        #expect(LoggerLevel.info.description == "info")
        #expect(LoggerLevel.notice.description == "notice")
        #expect(LoggerLevel.warning.description == "warning")
        #expect(LoggerLevel.error.description == "error")
        #expect(LoggerLevel.critical.description == "critical")
    }

    @Test("Default level is warning")
    func defaultLevel() {
        #expect(LoggerLevel.defaultLevel == .warning)
    }

    @Test("allCases is in declaration order")
    func allCasesOrder() {
        #expect(LoggerLevel.allCases == [
            .disabled, .trace, .debug, .info, .notice, .warning, .error, .critical
        ])
    }
}
