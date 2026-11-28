# mcp-server Specification

## Purpose

Gives coding agents bounded, read-only access to kafkalyzer's Kafka analysis functions through a local MCP server
that reaches only the cluster connections the user shared for that purpose.

## Requirements

### Requirement: Standalone MCP Server Over Standard Input And Output

The system SHALL provide a program that speaks the Model Context Protocol over its standard input and output and
runs without the desktop application being open. The program SHALL NOT open a network listener. It SHALL write
protocol messages only to standard output and diagnostics only to standard error, and SHALL exit when its standard
input is closed.

#### Scenario: Client starts the server and lists tools

- **WHEN** an MCP client starts the program, completes the initialization handshake and requests the tool list
- **THEN** the server SHALL answer with the twelve tools of the catalogue, each with a description and an input
  schema

#### Scenario: Desktop application is not running

- **WHEN** the program is started while the desktop application is closed
- **THEN** every tool SHALL work as when the application is open

#### Scenario: Client disconnects

- **WHEN** the client closes the server's standard input
- **THEN** the server SHALL stop running scans and exit

#### Scenario: Malformed request

- **WHEN** the server receives input that is not a valid protocol message
- **THEN** it SHALL answer with a protocol error where the protocol allows one and SHALL keep serving later requests

### Requirement: Only Shared Clusters Are Reachable

The server SHALL reach only cluster profiles that the user shared with headless binaries, and SHALL read the set
of shared profiles anew for every tool call. When the program is started with one or more cluster names, it SHALL
additionally refuse every profile not named. A tool call for any other cluster SHALL fail without contacting a
broker and without revealing whether an unshared profile of that name exists.

#### Scenario: Unshared cluster

- **WHEN** a tool is called for a cluster name that is not shared
- **THEN** the call SHALL fail with an error stating that the cluster is not available to the server
- **AND** no connection to any broker SHALL be opened

#### Scenario: Sharing is withdrawn while the server runs

- **WHEN** the user switches sharing off for a profile in the application and a tool is then called for it
- **THEN** the call SHALL fail as for an unshared cluster, without restarting the server

#### Scenario: Server restricted to one cluster

- **WHEN** the program is started restricted to "orders-test" and "orders-prod" is also shared
- **THEN** listing clusters SHALL return only "orders-test"
- **AND** a tool call for "orders-prod" SHALL fail as for an unshared cluster

#### Scenario: Cluster parameter omitted

- **WHEN** exactly one cluster is available to the server and a tool is called without a cluster name
- **THEN** the tool SHALL use that cluster
- **AND** when several clusters are available, the call SHALL fail and name the available clusters

#### Scenario: Shared profiles cannot be read

- **WHEN** the shared profile data is missing, unreadable, or a recorded secret of the requested profile is missing
  from the keyring
- **THEN** the tool call SHALL fail with an error that says so
- **AND** listing clusters SHALL NOT answer with an empty list as if nothing were shared when the data is unreadable

### Requirement: Cluster And Connection Tools

`kafka_list_clusters` SHALL return, for each available cluster, its name, environment tag, security protocol,
whether a Schema Registry is configured and whether TLS verification is disabled, and nothing else.
`kafka_test_connection` SHALL report whether the cluster can be reached with the shared profile.

#### Scenario: Listing clusters

- **WHEN** `kafka_list_clusters` is called and two clusters are available
- **THEN** the result SHALL list both names with the non-secret attributes named above
- **AND** the result SHALL contain no bootstrap server, user name, file path, password or token

#### Scenario: Connection test fails

- **WHEN** `kafka_test_connection` is called and the broker is unreachable or rejects the credentials
- **THEN** the tool SHALL return a failed result with the reason
- **AND** SHALL NOT report the cluster as reachable

### Requirement: Topic And Consumer Group Tools

`kafka_list_topics` SHALL return topics with partition count and replication factor, optionally narrowed by a
name filter. `kafka_list_consumer_groups` SHALL return groups with their state. `kafka_get_consumer_lag` SHALL
return one group's lag per topic and partition. `kafka_calculate_partition` SHALL return the partition the default
partitioner assigns to a key in a topic. Values that could not be determined SHALL be returned as unknown, never
as zero.

#### Scenario: Listing more topics than fit

- **WHEN** `kafka_list_topics` is called on a cluster with more topics than the result limit
- **THEN** the result SHALL hold at most the limit, state the total number and state that it was cut short

#### Scenario: Topic details

- **WHEN** `kafka_list_topics` is called
- **THEN** each topic SHALL also carry its cleanup policy and retention where the broker reports them, and unknown
  otherwise

#### Scenario: Topic not readable

- **WHEN** the service account may not describe a topic
- **THEN** the topic SHALL be reported as not readable, not left out and not reported with empty metadata

#### Scenario: Lag with partitions that cannot be read

- **WHEN** `kafka_get_consumer_lag` is called and the offsets of one partition cannot be read
- **THEN** that partition's lag SHALL be returned as unknown together with the reason
- **AND** the total SHALL be marked as incomplete

#### Scenario: Group has no committed offset

- **WHEN** a group has no committed offset for a partition
- **THEN** that partition SHALL be reported as "no commit", not as lag zero

#### Scenario: Unknown group or topic

- **WHEN** a tool is called for a group or topic that does not exist
- **THEN** the call SHALL fail with an error naming it, not return an empty result

#### Scenario: Calculating a partition

- **WHEN** `kafka_calculate_partition` is called with a key and a topic that has 12 partitions
- **THEN** the result SHALL be the partition the Kafka default partitioner assigns to that key for 12 partitions

### Requirement: Message Tools

`kafka_consume_messages` SHALL return messages of one topic from a chosen position, optionally of one partition.
`kafka_search_messages` SHALL return messages of one or more topics that match a filter on key, value or both.
`kafka_inspect_lagging_message` SHALL return the next message a consumer group has not yet processed on one
partition. Each message SHALL carry topic, partition, offset, timestamp, key, value, headers and, where known, the
schema it was decoded with.

#### Scenario: Reading the newest messages

- **WHEN** `kafka_consume_messages` is called for the newest 5 messages of a topic
- **THEN** the result SHALL hold at most 5 messages, each with its topic, partition, offset and timestamp

#### Scenario: Start positions

- **WHEN** `kafka_consume_messages` is called with the position oldest, newest, a given offset or a given timestamp
- **THEN** the returned messages SHALL start at that position

#### Scenario: Filter kinds

- **WHEN** `kafka_search_messages` is called with a contains, exact or regular-expression filter, optionally on
  one field addressed in the application's field path syntax
- **THEN** only messages matching that filter SHALL be returned

#### Scenario: Empty topic

- **WHEN** a message tool is called on a topic without messages
- **THEN** the result SHALL hold no message and state that the end of the topic was reached

#### Scenario: Search without match

- **WHEN** `kafka_search_messages` scans the requested range completely and nothing matches
- **THEN** the result SHALL hold no message and state that the scan was complete

#### Scenario: Invalid regular expression

- **WHEN** `kafka_search_messages` is called with a pattern that does not compile
- **THEN** the call SHALL fail with an error naming the pattern, before any broker is contacted

#### Scenario: Search over several topics

- **WHEN** `kafka_search_messages` is called for three topics
- **THEN** the message limit and the time limit SHALL apply to the call as a whole
- **AND** the result SHALL state per topic whether it was scanned completely, partly or not at all

#### Scenario: Lagging message on a topic with offset gaps

- **WHEN** `kafka_inspect_lagging_message` is called and no message exists at the committed offset because of
  compaction or transaction markers
- **THEN** the result SHALL hold the next existing message and SHALL state both the committed offset and the
  message's offset

#### Scenario: Group is caught up

- **WHEN** `kafka_inspect_lagging_message` is called and the committed offset equals the end of the partition
- **THEN** the result SHALL state that no unprocessed message exists, without a message

#### Scenario: Message cannot be decoded

- **WHEN** a value cannot be decoded because the Schema Registry is unreachable or the schema is unknown
- **THEN** the message SHALL still be returned with a note that decoding failed and why

### Requirement: Topic Analysis And Schema Tools

`kafka_analyze_topic` SHALL return the content analysis of one topic: message and byte counts, size statistics,
per-partition figures, key and content-type distribution, field frequencies and timeline. `kafka_list_schemas`
SHALL return the subjects of the cluster's Schema Registry. `kafka_get_schema` SHALL return one subject's schema
in a given or the latest version, with its type, id and version.

#### Scenario: Analysis stopped by a limit

- **WHEN** `kafka_analyze_topic` stops because the message or time limit was reached
- **THEN** the result SHALL be the analysis of the scanned part, marked as partial, with the number of scanned
  messages
- **AND** figures derived from offset ranges SHALL be labelled as estimates

#### Scenario: Analysis of an empty topic

- **WHEN** `kafka_analyze_topic` is called on a topic without messages
- **THEN** the result SHALL be a complete analysis with zero messages

#### Scenario: No Schema Registry configured

- **WHEN** a schema tool is called for a cluster without a Schema Registry
- **THEN** the call SHALL fail with an error stating that no Schema Registry is configured

#### Scenario: Schema Registry unreachable or access denied

- **WHEN** a schema tool is called and the registry does not answer or rejects the credentials
- **THEN** the call SHALL fail with an error that distinguishes the two cases, not return an empty subject list

#### Scenario: Unknown subject or version

- **WHEN** `kafka_get_schema` is called for a subject or version that does not exist
- **THEN** the call SHALL fail with an error naming the subject and version

### Requirement: Result And Time Limits

Every tool that reads messages SHALL stop at a message limit and a time limit: by default 20 returned messages
(10 000 analysed messages for `kafka_analyze_topic`) and 15 seconds. A caller can raise a limit only up to a fixed
ceiling of 100 returned messages, 100 000 analysed messages and 60 seconds; a higher value SHALL be reduced to the
ceiling and the result SHALL say so. Lists of topics, groups and subjects SHALL hold at most 500 entries. No tool
SHALL offer continuous tailing.

#### Scenario: Default message limit

- **WHEN** `kafka_consume_messages` is called without a limit on a topic with 1 000 messages
- **THEN** the result SHALL hold 20 messages and state that the message limit was reached

#### Scenario: Requested limit above the ceiling

- **WHEN** a message tool is called with a limit of 5 000
- **THEN** the result SHALL hold at most 100 messages and state that the requested limit was reduced to 100

#### Scenario: Time limit reached during a search

- **WHEN** a search has not finished after the time limit
- **THEN** the tool SHALL return the matches found so far and state that the time limit was reached and the scan
  is incomplete
- **AND** the scan SHALL stop reading from the broker

#### Scenario: Idle partition is not mistaken for the end

- **WHEN** a scan receives no data for a while before the time limit although the end of a partition was not
  signalled
- **THEN** the result SHALL NOT state that the scan was complete

#### Scenario: Client cancels a call

- **WHEN** the client cancels a running tool call
- **THEN** the scan SHALL stop reading from the broker and no result SHALL be sent for that call

#### Scenario: Many calls at once

- **WHEN** the client issues more tool calls at once than the server runs in parallel
- **THEN** the excess calls SHALL wait and then run; none SHALL be dropped silently

### Requirement: Payload Size Cap

Every message key, value and header value in a tool result SHALL be cut to a size cap, 4 KB by default and at most
32 KB on request. A value that was cut SHALL be marked as such and carry its original size. Sample values inside a
topic analysis and returned schema texts SHALL be subject to a cap in the same way. A complete tool result SHALL
NOT exceed 1 MB; when it would, entries SHALL be left out from the end and the result SHALL say so.

#### Scenario: Oversized value

- **WHEN** a message with a 50 KB value is returned with the default cap
- **THEN** the value in the result SHALL be at most 4 KB, marked as cut, with the original size of 50 KB
- **AND** the cut SHALL NOT split a character

#### Scenario: Cap raised by the caller

- **WHEN** a message tool is called with a cap of 1 MB
- **THEN** values SHALL be cut to 32 KB and the result SHALL state that the requested cap was reduced

#### Scenario: Large schema

- **WHEN** `kafka_get_schema` is called for a schema larger than the cap for schema texts
- **THEN** the schema text SHALL be cut and marked as cut with its original size

### Requirement: Internal Topics Need An Explicit Parameter

Topics whose name starts with an underscore SHALL be treated as internal. `kafka_list_topics` SHALL leave them out
and every tool that reads from a topic SHALL refuse them, unless the call carries the parameter that explicitly
includes internal topics.

#### Scenario: Listing without the parameter

- **WHEN** `kafka_list_topics` is called without the parameter on a cluster that has `__consumer_offsets`
- **THEN** the result SHALL NOT list it and SHALL state how many internal topics were left out

#### Scenario: Reading an internal topic without the parameter

- **WHEN** `kafka_consume_messages` is called for `__consumer_offsets` without the parameter
- **THEN** the call SHALL fail with an error naming the parameter, without contacting a broker

#### Scenario: Reading an internal topic with the parameter

- **WHEN** the same call carries the parameter
- **THEN** the tool SHALL read the topic under the usual limits

### Requirement: No Secrets In Results, Errors Or Diagnostics

No tool result, error message or diagnostic output SHALL contain a password, token or key password of any profile.
Diagnostic output SHALL NOT contain message keys, values or headers.

#### Scenario: Error text that repeats a credential

- **WHEN** a connection fails and the underlying error text contains the profile's password
- **THEN** the error returned to the client SHALL show a redaction marker in its place

#### Scenario: Diagnostics during a scan

- **WHEN** a message tool runs with diagnostic output enabled
- **THEN** standard error SHALL contain no message key, value or header

### Requirement: Tool Descriptions Name The Data Flow

The description of every tool that returns message content, schemas or cluster metadata SHALL state that the
returned data becomes part of the conversation and is therefore sent to the provider of the client's language
model. The description of every limited tool SHALL state its default limits and ceilings.

#### Scenario: Inspecting a tool description

- **WHEN** a client lists the tools
- **THEN** the description of `kafka_consume_messages` SHALL contain the data flow statement and its limits

### Requirement: MCP Server Stays Read-Only

The server SHALL perform only metadata and describe requests, consumption by manual partition assignment without
joining a consumer group and without committing offsets, and Schema Registry read requests. It SHALL offer no tool
and no parameter that produces, commits or resets offsets, or creates, alters or deletes topics, configurations,
consumer groups, ACLs, schemas or subjects.

#### Scenario: Inspecting a lagging message leaves the group untouched

- **WHEN** `kafka_inspect_lagging_message` is called for a consumer group
- **THEN** the group's committed offsets and its membership SHALL be the same after the call as before

#### Scenario: Reading leaves end offsets untouched

- **WHEN** any sequence of tools is called against a cluster
- **THEN** the end offsets of all topics SHALL be the same after the calls as before

#### Scenario: Tool catalogue offers no write

- **WHEN** a client lists the tools and their input schemas
- **THEN** no tool and no parameter SHALL trigger a write to Kafka or to the Schema Registry

### Requirement: Server Is Delivered With The Application

The release packages for Linux, macOS and Windows SHALL contain the MCP server program in the same version as the
application, at the location the application's configuration snippet names. The documentation SHALL describe how
to connect an MCP client, the limits, the data flow to the language model provider, and SHALL name a service
account restricted to read and describe permissions as a prerequisite for sharing a cluster.

#### Scenario: Installed package on each platform

- **WHEN** the application is installed from a release package on Linux, macOS or Windows and an MCP client is
  configured with the snippet the application shows
- **THEN** the client SHALL start the server and receive the tool list

#### Scenario: Version report

- **WHEN** the client completes the initialization handshake
- **THEN** the server SHALL report its name and the version of the release it belongs to

#### Scenario: Server program missing from a package

- **WHEN** a release build does not produce the server program for a platform
- **THEN** the build for that platform SHALL fail instead of publishing a package without it
