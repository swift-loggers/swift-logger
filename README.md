# swift-logger

A protocol-only logging core for Swift with zero external dependencies.
It provides a lightweight abstraction layer over logging backends.
The package defines a `Logger` protocol, a `LoggerLevel` type (five
severity levels plus a `disabled` sentinel value), and a `LoggerDomain`
subsystem identifier. Concrete loggers and integrations ship outside
the `Loggers` core product.

## Products

This package ships five products:

- `Loggers` — protocol-only core. The `Logger` protocol, `LoggerLevel`,
  and `LoggerDomain`. Zero dependencies.
- `LoggerPrint` — `PrintLogger`, a backend that writes log lines to
  standard output.
- `LoggerFiltering` — `DomainFilteredLogger`, a per-domain threshold
  decorator.
- `LoggerNoOp` — `NoOpLogger`, a backend that drops every message
  without evaluating its closure.
- `LoggerLibrary` — umbrella that re-exports the four products above
  for consumers who want the full surface from a single import.

## Installation

Add `swift-logger` as a dependency in `Package.swift`. Until the first
tagged release, track `main`:

```swift
.package(url: "https://github.com/swift-loggers/swift-logger", branch: "main")
```

Then pick one of the products as a target dependency:

```swift
// Protocol-only, zero dependencies, write your own backend:
.product(name: "Loggers", package: "swift-logger")

// Individual backends:
.product(name: "LoggerPrint", package: "swift-logger")
.product(name: "LoggerFiltering", package: "swift-logger")
.product(name: "LoggerNoOp", package: "swift-logger")

// Umbrella that re-exports all of the above:
.product(name: "LoggerLibrary", package: "swift-logger")
```

With `LoggerLibrary` a single `import LoggerLibrary` exposes the
protocol, `PrintLogger`, `DomainFilteredLogger`, and `NoOpLogger`.

## Conforming to `Logger`

The protocol has a single requirement. Implementations decide whether to
render, drop, or buffer log entries. Messages are provided as lazy
closures so implementations can avoid building log strings that are not
needed.

```swift
import Loggers

struct StdoutLogger: Logger {
    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        guard level != .disabled else { return }
        print("[\(level)] [\(domain)] \(message())")
    }
}
```

The convenience methods `verbose`, `debug`, `info`, `warning`, and
`error` are protocol extensions that forward to `log(_:_:_:)`, so
conforming types do not need to reimplement them.

> **Important:** Implementations MUST NOT evaluate the `message` closure
> when `level == .disabled`. This allows callers to include arbitrarily
> complex string-building work without paying for it when the message
> is suppressed.

> If you import both `Loggers` and Apple's `OSLog` in the same file, the
> `Logger` type name becomes ambiguous. Prefer explicit typing in mixed
> contexts, for example:
>
> ```swift
> let logger: any Loggers.Logger = StdoutLogger()
> ```

## Levels

`LoggerLevel` distinguishes five severity levels (`verbose`, `debug`,
`info`, `warning`, `error`) and a `disabled` sentinel.

`disabled` is a sentinel, not a severity level. It must never be used
as a threshold. It exists solely to mark individual log calls as
unconditionally skipped, allowing implementations to avoid even
evaluating the message closure.

A typical threshold-aware logger:

```swift
import Loggers

struct ThresholdLogger: Logger {
    let threshold: LoggerLevel

    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        guard threshold != .disabled, level != .disabled, level >= threshold else { return }
        print("[\(level)] [\(domain)] \(message())")
    }
}
```

The default severity (`LoggerLevel.defaultLevel`) is `.warning`.

## Domains

`LoggerDomain` identifies the subsystem a message comes from, enabling
filtering, grouping, and structured output (for example, JSON logs or
analytics pipelines). Define domains once per module as static
extensions:

```swift
import Loggers

extension LoggerDomain {
    static let network: LoggerDomain = "Network"
    static let database: LoggerDomain = "Database"
}
```

The raw value of a `LoggerDomain` is its identifier string and is part
of the public contract; it is suitable for log file or JSON output.

## Companion implementations

`LoggerPrint`, `LoggerFiltering`, and `LoggerNoOp` ship in this
package. Backends with external dependencies (for example, swift-log
or TCA integrations) ship in separate repositories under the
`swift-loggers` organization.

## Platforms

iOS 13, macOS 10.15, tvOS 13, watchOS 6, visionOS 1.

## License

MIT.
