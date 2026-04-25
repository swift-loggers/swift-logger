# swift-logger

A protocol-only logging core for Swift with zero external dependencies.
It provides a lightweight abstraction layer over logging backends.
The package defines a `Logger` protocol, a `LoggerLevel` type (five
severity levels plus a `disabled` sentinel value), and a `LoggerDomain`
subsystem identifier. Concrete loggers and integrations ship outside
the `Loggers` core product.

## Installation

Add `swift-logger` as a dependency in `Package.swift`. Until the first
tagged release, track `main`:

```swift
.package(url: "https://github.com/swift-loggers/swift-logger", branch: "main")
```

Add the `Loggers` product to your target dependencies:

```swift
.product(name: "Loggers", package: "swift-logger")
```

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

Concrete logger implementations and integrations ship outside the
`Loggers` core product.

## Platforms

iOS 13, macOS 10.15, tvOS 13, watchOS 6, visionOS 1.

## License

MIT.
