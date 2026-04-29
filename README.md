# swift-logger

A protocol-only logging core for Swift with no third-party dependencies
(it uses Foundation for `Date`-backed payloads).
It provides a lightweight abstraction layer over logging backends with
first-class support for structured attributes and privacy-aware string
interpolation. The package defines a `Logger` protocol, the `LogMessage`
/ `LogAttribute` / `LogRecord` payload types, a `LoggerLevel` (seven
severity levels plus a `disabled` sentinel), and a `LoggerDomain`
subsystem identifier. Concrete loggers and integrations ship outside
the `Loggers` core product.

## Products

This package ships five products:

- `Loggers` -- protocol-only core. The `Logger` protocol, the structured
  payload types (`LogMessage`, `LogSegment`, `LogPrivacy`, `LogValue`,
  `LogAttribute`, `LogRecord`), `LoggerLevel`, and `LoggerDomain`. No
  third-party dependencies; uses Foundation for `Date`-backed payloads.
- `LoggerPrint` -- `PrintLogger`, a backend that writes log lines to
  standard output. Honors privacy annotations via redaction.
- `LoggerFiltering` -- `DomainFilteredLogger`, a per-domain threshold
  decorator that forwards surviving entries upstream without
  evaluating the lazy payload.
- `LoggerNoOp` -- `NoOpLogger`, a backend that drops every entry without
  evaluating either the message or attributes closure.
- `LoggerLibrary` -- umbrella that re-exports the four products above
  for consumers who want the full surface from a single import.

## Installation

Add `swift-logger` as a dependency in `Package.swift` and pick a
product as a target dependency. Until the first tagged release, track
`main`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/swift-loggers/swift-logger", branch: "main")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                // Protocol-only, zero dependencies, write your own backend:
                .product(name: "Loggers", package: "swift-logger"),

                // Individual backends:
                .product(name: "LoggerPrint", package: "swift-logger"),
                .product(name: "LoggerFiltering", package: "swift-logger"),
                .product(name: "LoggerNoOp", package: "swift-logger"),

                // Umbrella that re-exports all of the above:
                .product(name: "LoggerLibrary", package: "swift-logger")
            ]
        )
    ]
)
```

## Quick start

The same `logger` carries plain strings, privacy-annotated
interpolation, and structured attributes -- one shape per operation,
not all three crammed into a single method:

```swift
import LoggerLibrary

extension LoggerDomain {
    static let auth: LoggerDomain = "Auth"
}

struct AuthService {
    let logger: any Logger

    func signOut() {
        logger.info(.auth, "User signed out")
    }

    func validate(username: String) {
        logger.debug(
            .auth,
            "Validating input for \(username, privacy: .private)"
        )
    }

    func signIn(username: String, password _: String) {
        let success = true
        logger.info(
            .auth,
            "Sign-in \(success ? "succeeded" : "failed")",
            attributes: [
                LogAttribute("auth.method", "password"),
                LogAttribute("auth.success", success),
                LogAttribute("auth.username", username, privacy: .private)
            ]
        )
        // Password is bound to `_` so the service never even names it
        // when logging; an HTTP client downstream owns the network
        // call and any HTTP-level logging.
    }
}
```

Guidelines:

- Message is human-readable.
- Attributes carry structured data for filtering and aggregation.
- Routes (`http.route`) are stable templates; identifiers go into
  separate attributes with explicit privacy.
- Credentials are never passed into the logger, even at
  `.sensitive` privacy.

## Conforming to `Logger`

The protocol has a single requirement. The `level` and `domain`
parameters are eagerly available, allowing implementations to decide
whether to drop an entry before evaluating either closure. Both
`message` and `attributes` are delivered as `@autoclosure @escaping
@Sendable` closures so implementations can drop entries without
evaluating them. This design guarantees that implementations can
perform filtering using only `level` and `domain`, without triggering
any user-provided work. Implementations should evaluate `message` and
`attributes` only after all drop conditions have been applied. Each
closure must be evaluated at most once per log entry.

```swift
import Foundation
import Loggers

struct StdoutLogger: Logger {
    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute]
    ) {
        guard level != .disabled else { return }
        let resolved = message().redactedDescription
        let resolvedAttributes = attributes()
        let attrs = resolvedAttributes.isEmpty
            ? ""
            : " {\(resolvedAttributes.map(\.redactedDescription).joined(separator: ", "))}"
        print("[\(level)] [\(domain)] \(resolved)\(attrs)")
    }
}
```

The convenience methods `trace`, `debug`, `info`, `notice`,
`warning`, `error`, and `critical` are protocol extensions in two
flavors -- `String` and `LogMessage` -- both with `attributes:`
defaulting to `[]`. Conforming types do not need to reimplement them.

> **Important:** Implementations MUST NOT evaluate the `message` or
> `attributes` closures when `level == .disabled`, and threshold-aware
> implementations MUST NOT evaluate them when `level` is below the
> configured threshold. Callers can therefore include arbitrarily
> expensive string-building or attribute-assembly work without paying
> for it when the entry is dropped.

> If you import both `Loggers` and Apple's `OSLog` in the same file,
> the `Logger` type name becomes ambiguous. Prefer explicit typing in
> mixed contexts: `let logger: any Loggers.Logger = StdoutLogger()`.

## Privacy-aware messages

`LogMessage` is `ExpressibleByStringLiteral` and
`ExpressibleByStringInterpolation`. Plain literals collapse into a
single `.public` segment; interpolations may carry a `privacy:` label:

```swift
import Loggers

let username = "alice"
let message: LogMessage = "User \(username, privacy: .private) signed in"
print(message.redactedDescription)
```

The default privacy on every interpolation is `.public`. Call sites
that include personally identifiable information must annotate the
interpolation explicitly with `privacy: .private` or
`privacy: .sensitive`. This mirrors the `os_log` `%{public}s`
convention; defaulting to `.private` would silently redact every plain
log message in development and was rejected for that reason.

Non-privacy-native sinks (for example `PrintLogger`) render messages
through `LogMessage.redactedDescription`, which substitutes segments
according to their privacy annotation:

| Privacy       | Rendering             |
|---------------|-----------------------|
| `.public`     | segment value verbatim |
| `.private`    | `<private>`           |
| `.sensitive`  | `<redacted>`          |

The same rule applies to `LogAttribute.redactedDescription`.

Privacy-native sinks (for example an OSLog adapter) may map segments
and attributes onto backend-specific primitives instead of using
textual redaction; adapters own these decisions, including transport,
storage, and redaction behavior.

## Structured attributes

The message is intended for human-readable context, while attributes
provide structured fields for filtering, aggregation, and analytics
in downstream systems.

Messages should remain concise and human-readable; attributes should
carry all data intended for querying, filtering, or aggregation.

`LogAttribute` carries a key, a `LogValue`, and an optional privacy
annotation:

```swift
import Loggers

let userID: LogValue = "abc-123"

let attributes: [LogAttribute] = [
    LogAttribute("path", "/v1/users"),
    LogAttribute("status", 200),
    LogAttribute("user", userID, privacy: .private),
    LogAttribute("tags", ["sso", "mfa"])
]
print(attributes.count)
```

`LogValue` is a sum type covering string, integer, double, boolean,
date, array, object, and null shapes, with `ExpressibleBy*Literal`
conformances for all of them. The synthesized `Codable` conformance
produces a debug-friendly JSON shape.

> **`LogValue.Codable` is not a vendor schema.** Remote adapters
> (Elasticsearch, Datadog, Splunk, Loki) own their own encoders and
> map `LogValue` onto each backend's native field, label, or tag
> model. Do not rely on the default `Codable` output for over-the-wire
> encoding.

> **Security:** Sensitive data such as passwords, tokens, or secrets
> must never be logged, even when marked as `.sensitive`. The
> `.sensitive` privacy level is intended for redaction, not for safe
> transport or storage.

## Levels

`LoggerLevel` is a transport-neutral severity model. It distinguishes
seven severity levels (`trace`, `debug`, `info`, `notice`, `warning`,
`error`, `critical`) and a `disabled` sentinel.

`disabled` is a sentinel, not a severity level. It must never be used
as a threshold. It exists solely to mark individual log calls as
unconditionally skipped, allowing implementations to avoid evaluating
the message or attributes closures.

The default severity (`LoggerLevel.defaultLevel`) is `.warning`.

Threshold-aware adapters expose their own nested
`MinimumLevel: CaseIterable, Sendable` enum with exactly seven cases:
`.trace`, `.debug`, `.info`, `.notice`, `.warning`, `.error`,
`.critical`. `.disabled` is never a valid threshold value.

## Domains

`LoggerDomain` identifies the subsystem a message comes from. Define
domains once per module as static extensions:

```swift
import Loggers

extension LoggerDomain {
    static let network: LoggerDomain = "Network"
    static let database: LoggerDomain = "Database"
    static let auth: LoggerDomain = "Auth"
}
```

The raw value of a `LoggerDomain` is its identifier string and is part
of the public contract; it is suitable for log file or JSON output.

## Companion implementations

`LoggerPrint`, `LoggerFiltering`, and `LoggerNoOp` ship in this
package. Backends with external dependencies (for example, swift-log,
OSLog, Datadog, or TCA integrations) ship in separate repositories
under the `swift-loggers` organization.

## Platforms

iOS 13, macOS 10.15, tvOS 13, watchOS 6, visionOS 1.

## License

MIT.
