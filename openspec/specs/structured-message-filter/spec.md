# structured-message-filter Specification

## Purpose

Defines the structured filter expression for broker-side topic scans: a small predicate tree over message key, value,
headers and metadata, its typed evaluation, its canonical text form, the builder and text editor, field suggestions
and its use in saved searches and script steps.

## Requirements

### Requirement: Filter Expression Structure

A filter expression SHALL be a tree of conditions combined with `AND`, `OR` and `NOT`, with parentheses for grouping.
`NOT` SHALL bind tighter than `AND`, and `AND` tighter than `OR`. Keywords SHALL be accepted in any letter case. An
empty or whitespace-only expression SHALL mean "no expression". Aggregations, joins, projections and functions SHALL NOT
be part of the language.

#### Scenario: Precedence without parentheses
- **WHEN** the expression `partition == 1 OR partition == 2 AND offset > 10` is evaluated for a message in partition 1
  at offset 5
- **THEN** the message SHALL match, because the expression is read as `partition == 1 OR (partition == 2 AND offset > 10)`

#### Scenario: Parentheses override precedence
- **WHEN** the expression `(partition == 1 OR partition == 2) AND offset > 10` is evaluated for a message in partition 1
  at offset 5
- **THEN** the message SHALL NOT match

#### Scenario: Negation
- **WHEN** the expression `NOT value exists` is evaluated for a tombstone (a message without value)
- **THEN** the message SHALL match

#### Scenario: Function call rejected
- **WHEN** the user enters `len(value.items) > 2`
- **THEN** the expression SHALL be rejected as invalid with the position of `(`

### Requirement: Condition Sources

A condition SHALL read exactly one source: `key` or `value` (whole text, or a field path into the decoded JSON),
`header.<name>`, `partition`, `offset` or `timestamp`. The whole-text form of `key` and `value` SHALL be the same text
the message table shows for that message. An unknown source name SHALL make the expression invalid.

#### Scenario: Whole value text
- **WHEN** the expression `value contains "timeout"` is evaluated for a message whose displayed payload contains
  `timeout`
- **THEN** the message SHALL match

#### Scenario: Field of the decoded value
- **WHEN** the expression `value.order.status == "FAILED"` is evaluated for a Schema-Registry-encoded Avro message whose
  decoded value has `order.status` = `FAILED`
- **THEN** the message SHALL match

#### Scenario: Field of the key
- **WHEN** the expression `key.tenant == "acme"` is evaluated for a message whose key is the JSON `{"tenant":"acme"}`
- **THEN** the message SHALL match

#### Scenario: Unknown source
- **WHEN** the user enters `payload.id == 1`
- **THEN** the expression SHALL be rejected as invalid at the position of `payload`

### Requirement: One Path Language In Expressions

A field path in a condition SHALL be resolved with the application's single field-path language (dot keys, `[n]` or
dot indices, optional `$.` prefix, JSON Pointer). A path that contains characters outside letters, digits, `_`, `-`,
`$`, `.`, `[` and `]`, or starts with `/`, SHALL be written as a double-quoted string after the source and its dot.
Wildcards and filter expressions inside paths SHALL NOT be accepted.

#### Scenario: Same value as a projected column
- **WHEN** a scan uses `value.items[0].sku == "A-1"` and the user projects the column `items[0].sku`
- **THEN** every returned message SHALL show `A-1` in that column

#### Scenario: Quoted JSON Pointer path
- **WHEN** the user enters `value."/a~1b/c" == 1` for a payload `{"a/b":{"c":1}}`
- **THEN** the message SHALL match

#### Scenario: Wildcard rejected
- **WHEN** the user enters `value.items[*].sku == "A-1"`
- **THEN** the expression SHALL be rejected as invalid at the position of `*`

### Requirement: Comparison Operators

Conditions SHALL support `==`, `!=`, `<`, `<=`, `>`, `>=`, `contains` (case-sensitive substring), `matches` (regular
expression found anywhere in the text) and the postfix `exists`. `contains` and `matches` SHALL require a string
literal and SHALL only apply to `key`, `value` and header sources; using them on `partition`, `offset` or `timestamp`
SHALL make the expression invalid.

#### Scenario: Regular expression
- **WHEN** the expression `header.traceId matches "^abc-[0-9]+$"` is evaluated for a message with header
  `traceId: abc-42`
- **THEN** the message SHALL match

#### Scenario: Contains on a number source rejected
- **WHEN** the user enters `offset contains "12"`
- **THEN** the expression SHALL be rejected as invalid at the position of `contains`

#### Scenario: Exists on a field
- **WHEN** the expression `value.error exists` is evaluated for payloads `{"error":"x"}` and `{"ok":true}`
- **THEN** only the first message SHALL match

### Requirement: Typed Comparison

The literal type SHALL select the comparison. A number literal SHALL compare numerically: JSON numbers, and texts that
are a complete decimal number, are numeric; integers SHALL compare exactly. A string literal SHALL compare with the
field's displayed text (strings without quotes, numbers and booleans as written in JSON). `true`/`false` SHALL match
JSON booleans and the texts `true`/`false`. A field that cannot be read as the literal's type SHALL not satisfy `==`,
`<`, `<=`, `>`, `>=`.

#### Scenario: Numeric comparison
- **WHEN** the expression `value.amount > 100` is evaluated for payloads with `amount` 150, `"150"` and `"n/a"`
- **THEN** the first two messages SHALL match and the third SHALL NOT

#### Scenario: Text comparison against a number field
- **WHEN** the expression `value.code == "007"` is evaluated for a payload with `code` = 7 (number)
- **THEN** the message SHALL NOT match, because the displayed text is `7`

#### Scenario: Large integer identifiers
- **WHEN** the expression `value.id == 9007199254740993` is evaluated for a payload with `id` = 9007199254740993
- **THEN** the message SHALL match, and a payload with `id` = 9007199254740992 SHALL NOT

#### Scenario: Not equal on a mismatching type
- **WHEN** the expression `value.amount != 5` is evaluated for a payload with `amount` = `"n/a"`
- **THEN** the message SHALL match, because the resolved value is not equal to 5

#### Scenario: Ordering with a boolean rejected
- **WHEN** the user enters `value.active > true`
- **THEN** the expression SHALL be rejected as invalid at the position of `true`

### Requirement: Unresolvable Values Make A Condition False

A condition whose source has no value SHALL evaluate to false for every operator, including `!=`, and SHALL NOT raise
an error or stop the scan. This covers a path that does not exist, a value or key that is not JSON, JSON `null`, a
missing key or value, a missing header and a message without a known timestamp. `NOT` applied to such a condition SHALL
be true.

#### Scenario: Missing field
- **WHEN** the expression `value.customer.id != "42"` is evaluated for a payload without `customer`
- **THEN** the message SHALL NOT match and the scan SHALL continue

#### Scenario: Non-JSON payload with a path
- **WHEN** the expression `value.status == "OK"` is evaluated for a plain-text payload
- **THEN** the message SHALL NOT match

#### Scenario: Unknown timestamp
- **WHEN** the expression `timestamp > 0` is evaluated for a message whose broker timestamp is not available
- **THEN** the message SHALL NOT match, and `NOT timestamp > 0` SHALL match it

### Requirement: Header Conditions

A `header.<name>` condition SHALL compare the header value as text: UTF-8 values as text, other bytes in the same
hexadecimal form the inspector shows. Header names SHALL be compared case-sensitively. When a message carries several
headers with the name, the condition SHALL be true if any of them satisfies it. A header present with a null value
SHALL satisfy `exists` and no other operator.

#### Scenario: Header equality
- **WHEN** the expression `header.eventType == "OrderCreated"` is evaluated for a message with header
  `eventType: OrderCreated`
- **THEN** the message SHALL match

#### Scenario: Repeated header
- **WHEN** the expression `header.tag == "b"` is evaluated for a message with headers `tag: a` and `tag: b`
- **THEN** the message SHALL match

#### Scenario: Header name with special characters
- **WHEN** the user enters `header."x trace id" exists`
- **THEN** the condition SHALL test the header named `x trace id`

#### Scenario: Null header value
- **WHEN** the expressions `header.flag exists` and `header.flag == ""` are evaluated for a message whose header `flag`
  has a null value
- **THEN** the first SHALL match and the second SHALL NOT

### Requirement: Timestamp Literals

A `timestamp` condition SHALL compare the message timestamp in epoch milliseconds. Its literal SHALL be either a number
(epoch milliseconds) or a string in ISO-8601 / RFC 3339 form with an explicit UTC offset or `Z`; the string SHALL be
converted once before the scan. A string without offset or with an invalid date SHALL make the expression invalid.

#### Scenario: ISO literal
- **WHEN** the expression `timestamp >= "2026-03-01T00:00:00Z"` is evaluated for a message with timestamp
  1772323200000
- **THEN** the message SHALL match

#### Scenario: Missing offset rejected
- **WHEN** the user enters `timestamp > "2026-03-01T10:00:00"`
- **THEN** the expression SHALL be rejected as invalid at the position of the literal, stating that a UTC offset is
  required

### Requirement: Validation Before The Scan Starts

The system SHALL validate an expression, including its regular expressions and timestamp literals, before a scan
starts and while the user edits it. An invalid expression SHALL refuse the scan and SHALL be reported in the active UI
language at the input with the position (column) of the error. No scan SHALL run with a partially applied expression.

#### Scenario: Syntax error with position
- **WHEN** the user enters `value.status == "FAILED" AND` and starts the scan
- **THEN** the scan SHALL NOT start
- **AND** the input SHALL show a localized error stating that the expression ends unexpectedly at column 29 and SHALL
  mark that position

#### Scenario: Invalid regular expression
- **WHEN** the user enters `key matches "orders["`
- **THEN** the input SHALL show an invalid-pattern error at the position of the literal and the scan SHALL NOT start

#### Scenario: Valid expression
- **WHEN** the user enters a valid expression and starts the scan
- **THEN** no validation error SHALL be shown and the scan SHALL start

#### Scenario: Scan requested without prior validation
- **WHEN** a scan is requested through any entry point with an invalid expression
- **THEN** the scan SHALL fail before reading any message and SHALL report the error, never an empty result

### Requirement: Payload Decoding Only When Referenced

An expression that does not reference `value` SHALL be evaluated without decoding the payload; the payload SHALL then
be decoded only for messages that match. The same SHALL hold for `key` and for headers. Evaluation SHALL stop as soon
as the result of `AND`, `OR` and `NOT` is determined.

#### Scenario: Key-only expression
- **WHEN** a scan with the expression `key == "order-4711"` reads 10,000 messages of which 1 matches
- **THEN** the payload SHALL be decoded for at most the 1 matching message

#### Scenario: Metadata short-circuit
- **WHEN** the expression `partition == 3 AND value.status == "FAILED"` is evaluated for a message in partition 0
- **THEN** the payload of that message SHALL NOT be decoded

### Requirement: Coexistence With The Text Filter

The existing text filter (terms with Contains, Regex or Exact, optional field, scope Key, Value or Both) SHALL keep its
behaviour unchanged. When a scan has both text-filter terms and an expression, a message SHALL be returned only if it
satisfies both. Fast Trace SHALL keep selecting its partition from the first text-filter term only.

#### Scenario: Text filter alone
- **WHEN** a scan uses only the term `abc` with Contains and scope Both
- **THEN** it SHALL return exactly the messages it returned before this change

#### Scenario: Both filters
- **WHEN** a scan uses the term `abc` and the expression `partition == 2`
- **THEN** only messages in partition 2 containing `abc` SHALL be returned

### Requirement: Canonical Text Form

Every valid expression SHALL have one canonical text: keywords `AND`, `OR`, `NOT` in upper case; operators and `exists`
in lower case; single spaces between tokens; parentheses only where precedence requires them; nested groups of the
same operator flattened; string literals in double quotes with `\"`, `\\` and control-character escapes; number
literals and paths as entered. Parsing the canonical text SHALL give the same tree.

#### Scenario: Normalization
- **WHEN** the user enters `not (value.a==1) and ((key contains "x"))`
- **THEN** the canonical text SHALL be `NOT value.a == 1 AND key contains "x"`

#### Scenario: Round trip
- **WHEN** any valid expression is converted to canonical text and parsed again
- **THEN** the resulting tree SHALL equal the original tree

### Requirement: Builder And Text Modes

The expression editor SHALL offer a condition builder and a text input with the same expressive power. The builder
SHALL show nested `AND`/`OR` groups, a negation toggle per group and condition, and each condition as a chip with
source, path, operator and typed literal. Switching modes SHALL keep the expression; text that is invalid SHALL NOT be
switched to the builder and its error SHALL stay visible.

#### Scenario: Text to builder
- **WHEN** the user switches to the builder with the text `(header.type == "A" OR header.type == "B") AND NOT offset < 100`
- **THEN** the builder SHALL show an `AND` group containing an `OR` group with two header chips and a negated offset chip

#### Scenario: Builder to text
- **WHEN** the user builds conditions in the builder and switches to text
- **THEN** the text SHALL be the canonical text of the built tree, and switching back SHALL show the same builder state

#### Scenario: Literal type kept
- **WHEN** the user sets the literal of `value.code ==` to the text `42` in the builder and switches to text
- **THEN** the text SHALL contain `"42"`, not the number `42`

#### Scenario: Invalid text blocks switching
- **WHEN** the text contains a syntax error and the user selects the builder
- **THEN** the editor SHALL stay in text mode and show the localized error with its position

#### Scenario: Accessible controls
- **WHEN** a screen reader focuses a condition chip, a group negation toggle or the mode switch
- **THEN** each SHALL expose a localized label, and icon-only controls SHALL have a tooltip

### Requirement: Field Suggestions

Path inputs in the editor SHALL suggest field paths from the topic's value schema when it can be read; otherwise from
the field frequencies of a loaded topic analysis of the same topic; otherwise from the messages currently loaded.
Header-name inputs SHALL suggest header names of loaded messages. The suggestion list SHALL name its source. When no
source is available the list SHALL say so instead of appearing empty.

#### Scenario: Schema available
- **WHEN** the topic has a readable value schema with field `order.status`
- **THEN** typing `order.` in a value path SHALL suggest `order.status`, labelled as coming from the schema

#### Scenario: Schema unavailable
- **WHEN** reading the schema fails or the topic has none, and 50 messages are loaded
- **THEN** suggestions SHALL come from those messages and be labelled as such

#### Scenario: No source
- **WHEN** no schema, no analysis and no loaded messages exist for the topic
- **THEN** the suggestion area SHALL state that no field suggestions are available and free input SHALL remain possible

### Requirement: Expression In Script Steps

A script step SHALL be able to carry a filter expression next to its text filter, with the same validation and
editor. Scripts saved without an expression SHALL load and run unchanged. Search parameters written with script or
search results SHALL include the expression text when one is set.

#### Scenario: Old script
- **WHEN** a script saved before this change is loaded and run
- **THEN** every step SHALL behave exactly as before

#### Scenario: Step with expression
- **WHEN** a step with the expression `header.eventType == "OrderCreated"` runs
- **THEN** only messages with that header SHALL be returned and the written search parameters SHALL contain the
  expression

#### Scenario: Invalid stored expression
- **WHEN** a script step's stored expression is invalid
- **THEN** the step editor SHALL show it with its error, and running the step SHALL fail with that error instead of
  running unfiltered

### Requirement: Script Variables In Expressions

A script variable SHALL be usable as a literal: `"…{{name}}…"` inside a string literal inserts the value as text;
`{{name}}` alone in literal position SHALL be a number and SHALL fail if the value is not a number. Values SHALL never
be parsed as expression syntax. With several comma-separated values a condition SHALL be true if any value satisfies
it; `!=` SHALL be true only if the value equals none of them. An unknown variable SHALL fail the step.

#### Scenario: Text placeholder with quotes in the value
- **WHEN** the variable `id` holds `a"b` and the step expression is `value.id == "{{id}}"`
- **THEN** the condition SHALL compare with the text `a"b` and the expression SHALL stay valid

#### Scenario: Multi-value variable
- **WHEN** the variable `ids` holds `A1, B2` and the expression is `key == "{{ids}}"`
- **THEN** messages with key `A1` or `B2` SHALL match
- **AND** with `key != "{{ids}}"` messages with key `A1` or `B2` SHALL NOT match

#### Scenario: Numeric placeholder
- **WHEN** the variable `min` holds `abc` and the expression is `value.amount > {{min}}`
- **THEN** the step SHALL fail with a localized error naming the variable `min`

#### Scenario: Unknown variable
- **WHEN** an expression references `{{missing}}` and no such variable has a value
- **THEN** the step SHALL fail with an error naming `missing` and SHALL NOT scan with the placeholder text

#### Scenario: Headless run
- **WHEN** the same script runs headless with `--var ids=A1,B2`
- **THEN** the step SHALL return the same messages as in the desktop run

### Requirement: Expression Size Limits

The system SHALL reject an expression longer than 65,536 characters, nested deeper than 64 levels, or whose script
variables expand to more than 10,000 literal alternatives, with a localized error, before the scan starts.

#### Scenario: Too deeply nested
- **WHEN** an expression with 65 nested parentheses is validated
- **THEN** it SHALL be rejected as too complex and SHALL NOT crash the application

#### Scenario: Too many alternatives
- **WHEN** a step expression uses two multi-value variables with 200 values each in one literal
- **THEN** the step SHALL fail with a too-complex error before scanning

### Requirement: Read-Only Filtering

Filtering by expression SHALL use only the existing read-only scan: manual partition assignment without consumer group
membership or offset commits. Field suggestions SHALL use only existing read-only Schema Registry reads and local data.
Validating, formatting and suggesting SHALL NOT contact the cluster.

#### Scenario: Validation offline
- **WHEN** the user edits and validates an expression
- **THEN** no Kafka or Schema Registry request SHALL be issued for it

#### Scenario: Scan with expression
- **WHEN** a scan with an expression runs
- **THEN** it SHALL NOT join a consumer group, commit offsets or write to Kafka or the Schema Registry
