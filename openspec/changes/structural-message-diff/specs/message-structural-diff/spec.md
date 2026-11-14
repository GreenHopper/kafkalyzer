# Spec Delta

## Purpose

Defines how kafkalyzer compares two JSON message payloads field by field — one shared result model for the diff view
and later consumers (poison-pill compare, script-run comparison, MCP) — and how the diff view presents that result,
including a per-topic list of ignored field paths.

## ADDED Requirements

### Requirement: Flat Structural Difference List
The system SHALL compare two JSON documents and return a flat list of differences. Each entry SHALL carry a field path, its path segments, a kind (`added`, `removed` or `changed`), the old value and the new value as JSON text. For the same two inputs the list SHALL always have the same content and order: depth-first in document order, keys of the old document first, keys only present in the new document after them.

#### Scenario: Changed, added and removed fields
- **WHEN** `{"a":1,"b":2,"c":3}` is compared with `{"a":1,"b":5,"d":4}`
- **THEN** the result SHALL be exactly: `b` changed from `2` to `5`, `c` removed with old value `3`, `d` added with new value `4`, in this order

#### Scenario: Identical documents
- **WHEN** two documents are compared that differ only in object key order or whitespace
- **THEN** the result SHALL contain no entry

#### Scenario: Whole subtree added
- **WHEN** the new document contains an object field `meta` that the old document lacks
- **THEN** the result SHALL contain one `added` entry for `meta` whose new value is the whole object, not one entry per nested field

### Requirement: Difference Paths Use the Canonical Path Grammar
Each difference path SHALL be written in the field-path grammar of `json-path-resolution` and SHALL resolve, against the document that contains the value, to that value. A difference of the whole document SHALL have an empty path.

#### Scenario: Nested and indexed path resolves
- **WHEN** a difference is reported inside the second element of the array `items`
- **THEN** its path SHALL select that element's field when resolved against the document that contains the value

#### Scenario: Key that cannot be written in dot notation
- **WHEN** a difference is reported under the key `app.kubernetes.io/name`
- **THEN** the path SHALL use the JSON Pointer form of the grammar and SHALL resolve to that key

#### Scenario: Different top-level types
- **WHEN** an object is compared with an array at the top level
- **THEN** the result SHALL contain one `changed` entry with an empty path holding both documents

### Requirement: Null, Missing and Type Changes Are Distinguished
A field that is missing on one side SHALL be reported as `added` or `removed` with no value on the missing side. A field whose value is JSON `null` SHALL be present with the value `null`. A value whose JSON type differs between the sides SHALL be one `changed` entry holding both complete values. Numbers SHALL be equal when their numeric values are equal.

#### Scenario: Null versus missing
- **WHEN** `{"a":null}` is compared with `{}`
- **THEN** the result SHALL contain `a` removed with old value `null` and no new value

#### Scenario: Null versus a value
- **WHEN** `{"a":null}` is compared with `{"a":1}`
- **THEN** the result SHALL contain `a` changed from `null` to `1`

#### Scenario: Type change
- **WHEN** `{"a":{"x":1}}` is compared with `{"a":[1]}`
- **THEN** the result SHALL contain one `changed` entry for `a` with both complete values and no entry below `a`

#### Scenario: Integer and decimal notation of the same number
- **WHEN** `{"a":1}` is compared with `{"a":1.0}`
- **THEN** the result SHALL contain no entry

### Requirement: Array Alignment With Bounded Cost
Arrays SHALL be compared by removing the longest common prefix and suffix of equal elements and pairing the remaining elements by position; unpaired elements SHALL be `added` or `removed`. The comparison cost SHALL grow linearly with the array length, not with the product of both lengths. A reordered array SHALL NOT be reported as unchanged.

#### Scenario: Element inserted in the middle
- **WHEN** `["a","b","c"]` is compared with `["a","x","b","c"]`
- **THEN** the result SHALL contain exactly one `added` entry at index 1 with the value `"x"`

#### Scenario: Element changed in place
- **WHEN** an array of objects differs only in one field of its third element
- **THEN** the result SHALL contain one `changed` entry for that field below index 2

#### Scenario: Reordered array
- **WHEN** `[1,2,3]` is compared with `[3,1,2]`
- **THEN** the result SHALL contain at least one entry

#### Scenario: Large array
- **WHEN** two arrays with 100,000 elements each are compared
- **THEN** the comparison SHALL complete without pairwise comparison of every element with every other element

### Requirement: Non-JSON Input Is Reported
When either side is not valid JSON the comparison SHALL report which side is not JSON and SHALL return no structural entries. This outcome SHALL NOT be presented as "no differences".

#### Scenario: One side is plain text
- **WHEN** a JSON document is compared with the text `hello`
- **THEN** the result SHALL state that the new side is not JSON and contain no entry

#### Scenario: Diff view with a non-JSON payload
- **WHEN** a diff card compares two payloads of which one is not JSON
- **THEN** the card SHALL show the payload text as before and SHALL NOT show "No differences found."

### Requirement: Ignored Field Paths
A comparison SHALL accept a list of field paths in the grammar of `json-path-resolution`; wildcards are not part of that grammar. An entry whose path equals an ignored path or lies below it SHALL be removed from the result and counted as hidden. An entry above an ignored path, and the whole-document entry, SHALL NOT be hidden.

#### Scenario: Exact path hidden
- **WHEN** `{"id":1,"ts":5}` is compared with `{"id":1,"ts":9}` with the ignored path `ts`
- **THEN** the result SHALL contain no entry and report one hidden entry

#### Scenario: Subtree hidden
- **WHEN** the ignored path is `meta` and the fields `meta.ts` and `meta.host` changed
- **THEN** both entries SHALL be hidden and two hidden entries SHALL be reported

#### Scenario: Notation independence
- **WHEN** the ignored path is written `$.items[0].ts` or `/items/0/ts`
- **THEN** it SHALL hide the difference at `items` index 0 field `ts` in both cases

#### Scenario: Sibling key is not a prefix match
- **WHEN** the ignored path is `a.b` and the field `a.bc` changed
- **THEN** the change of `a.bc` SHALL be reported

#### Scenario: Unusable ignore entry
- **WHEN** an ignored path is empty
- **THEN** it SHALL hide nothing and the comparison SHALL still succeed

### Requirement: Bounded Result Size
A comparison SHALL accept an optional maximum number of entries. When more entries exist the result SHALL contain the first entries in the defined order, the total number of entries and a truncation flag. The diff view SHALL show how many differences are not displayed.

#### Scenario: Result truncated
- **WHEN** a comparison with a maximum of 2 entries finds 5 differences
- **THEN** the result SHALL contain the first 2 entries, a total of 5 and the truncation flag

#### Scenario: Truncation shown in the diff view
- **WHEN** a diff card receives a truncated result
- **THEN** the card SHALL show a localized notice with the number of differences not shown

### Requirement: Diff View Compares Each Message With Its Predecessor
The diff view SHALL compare each loaded message with the chronologically previous loaded message of the same topic and key, in the display order of the result list. A message without predecessor SHALL show its payload preview instead of a diff. An empty or absent payload SHALL be compared as an empty object, as before.

#### Scenario: Two versions of a key
- **WHEN** the list contains two messages of topic `orders` with key `42` and payloads `{"val":10}` and `{"val":20}`
- **THEN** the later message's card SHALL show `val` changed from `10` to `20`

#### Scenario: First message of a key
- **WHEN** a message has no earlier message with the same topic and key in the list
- **THEN** its card SHALL show the payload preview and no diff

### Requirement: Diff Rendering Is Preserved
The diff view SHALL render differences as before: grouped per level as added, removed, changed, then nested fields, with the existing icons, colours, indentation, collapsible nested nodes and "No differences found." text. Only the cases defined as defects by this capability (reordered arrays, equal top-level values) MAY render differently.

#### Scenario: Unchanged rendering for a nested change
- **WHEN** a diff with a changed nested field, an added field and a removed field is shown
- **THEN** the rows, their order, keys, values, icons and indentation SHALL equal the rendering before this capability existed

#### Scenario: No differences after ignoring
- **WHEN** every difference of a card is hidden by the ignore list
- **THEN** the card SHALL show "No differences found." together with the hidden count

### Requirement: Diff Computation Stays Responsive
Diffs SHALL be computed in the background in batches for the visible cards, each pending card SHALL show a loading indicator, and a failed computation SHALL show a localized error on the card instead of an empty result.

#### Scenario: Large payload
- **WHEN** a card compares two 5 MB JSON payloads
- **THEN** the view SHALL stay scrollable while the card shows a loading indicator

#### Scenario: Computation fails
- **WHEN** the background comparison raises an error
- **THEN** the affected cards SHALL show the localized "Error computing diff" text

### Requirement: Per-Topic Ignore List in the Diff View
The diff view SHALL let the user add and remove ignored field paths per topic, from a dialog and from a row action "Ignore this field". The list SHALL be stored locally per topic name and survive restarts; changing it SHALL recompute the affected cards. Each card SHALL show "hidden (n)" when n entries were hidden.

#### Scenario: Ignore from a diff row
- **WHEN** the user chooses "Ignore this field" on the row `ts` of a card of topic `orders`
- **THEN** `ts` SHALL be added to the ignore list of `orders`, the card SHALL no longer show `ts` and SHALL show "hidden (1)"

#### Scenario: List survives restart
- **WHEN** the application is restarted and a diff of topic `orders` is opened
- **THEN** the previously ignored paths of `orders` SHALL be applied

#### Scenario: Other topics unaffected
- **WHEN** `ts` is ignored for topic `orders`
- **THEN** cards of topic `payments` SHALL still show changes of `ts`

#### Scenario: Stored list cannot be read
- **WHEN** the stored ignore list of a topic is unreadable
- **THEN** the view SHALL show a localized warning, compute diffs without that list, SHALL NOT show a hidden count for it, and SHALL NOT overwrite the stored value until the user edits the list

#### Scenario: Saving fails
- **WHEN** storing a changed ignore list fails
- **THEN** a localized error SHALL be shown and the change SHALL be reported as not saved

### Requirement: Suggestions for Volatile Fields
The ignore-list dialog SHALL suggest paths that changed in the loaded diffs of the topic and whose last key names a typical volatile field (timestamps, dates, ids). Suggestions SHALL only be added on explicit user action and SHALL never be enabled automatically.

#### Scenario: Timestamp field suggested
- **WHEN** loaded diffs of topic `orders` contain a change of `updatedAt` and the ignore list is empty
- **THEN** the dialog SHALL offer `updatedAt` as a suggestion and the diffs SHALL still show the change

#### Scenario: Accepting a suggestion
- **WHEN** the user accepts the suggestion `updatedAt`
- **THEN** it SHALL be added to the ignore list of `orders` and the affected cards SHALL be recomputed
