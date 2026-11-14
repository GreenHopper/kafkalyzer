# explorer-onboarding Specification

## Purpose

Provides guided onboarding and actionable empty states across the Explorer workflow, enabling zero-friction cluster connection, instant cluster overview visibility, and 1-click message fetching when topic tabs contain no messages.

## Requirements

### Requirement: Interactive Cluster Selection Empty State

When no cluster is actively selected in the Explorer view, the main content area SHALL display an interactive onboarding dashboard featuring selectable cluster cards for all configured profiles, a prominent action to configure a new cluster, and a list of recently viewed topics.

#### Scenario: Clicking a cluster card connects immediately
- **WHEN** the Explorer view has no active cluster connection
- **AND** the user clicks on a cluster card in the onboarding dashboard
- **THEN** the system SHALL select that cluster profile, initiate the connection, and load its topic list into the sidebar

#### Scenario: Onboarding with no configured clusters
- **WHEN** no cluster profiles are configured in the application
- **AND** the Explorer view is displayed
- **THEN** the onboarding dashboard SHALL display a welcoming guide with a primary action button to create or import a cluster profile

#### Scenario: Opening a recently viewed topic from cluster onboarding
- **WHEN** the user selects an entry from the recently viewed topics list on the cluster onboarding dashboard
- **THEN** the system SHALL connect to that topic's associated cluster if not already connected
- **AND** open a tab for that topic in the Explorer view

### Requirement: Cluster Overview Dashboard Empty State

When a cluster is actively selected but no topic tab is open in the Explorer view, the main content area SHALL display an informative cluster overview showing cluster connection metadata, total topic count, Schema Registry status, and quick access to recently viewed topics for that cluster.

#### Scenario: Displaying cluster overview metrics
- **WHEN** an active cluster connection is established and all topic tabs are closed
- **THEN** the Explorer main content area SHALL display the cluster name, bootstrap server address, total number of topics, and Schema Registry configuration indicator
- **AND** display quick-launch cards or list items for recently opened topics belonging to this cluster

#### Scenario: Opening a recent topic from the cluster overview
- **WHEN** the user clicks on a recent topic card in the cluster overview
- **THEN** the system SHALL open a new search tab for that topic and focus it

### Requirement: Actionable Empty State in Topic Message View

When a topic tab is open with zero loaded messages and message consumption is inactive (`isStreaming = false`), the message area SHALL display an actionable empty state card with a primary action button to fetch messages immediately using the current configuration, and a helpful tip indicating that double-clicking topics in the sidebar starts fetching automatically. When the last consumption attempt in that tab failed, the message area SHALL show the consumption error state instead of this empty state.

#### Scenario: Triggering message fetch from actionable empty state
- **WHEN** a topic tab is open with 0 loaded messages and `isStreaming` is false
- **AND** the user clicks the primary "Fetch latest messages" action button in the empty state card
- **THEN** the system SHALL initiate bounded message consumption with the current configuration (defaulting to latest 200 messages) without requiring navigation to external buttons

#### Scenario: Active streaming suppresses empty state
- **WHEN** message consumption is actively streaming or loading messages
- **THEN** the actionable empty state card SHALL be hidden and replaced with the active streaming progress or message viewport

#### Scenario: Localized empty state rendering
- **WHEN** the application is running under German or English locale
- **THEN** all titles, descriptions, button labels, and helper tips in the actionable empty state SHALL be rendered using localized strings from `AppLocalizations` without hardcoded English text

#### Scenario: Failed consumption does not show the empty state
- **WHEN** a topic tab has 0 loaded messages and its last consumption attempt ended with an error
- **THEN** the "No messages loaded yet" empty state card SHALL NOT be shown
- **AND** the consumption error state SHALL be shown instead

### Requirement: Load Failure Error States in Explorer

A failure while consuming messages, loading the topic list or loading Schema Registry subjects SHALL be shown as a localized error state that names the cause and offers a "Retry" action, visibly distinct from the corresponding empty state. A failure SHALL NOT be shown as zero messages, zero topics or "no schema". Retry SHALL repeat only the same read-only fetch. A cluster without a configured Schema Registry is not a subject load failure.

#### Scenario: Consumption failure before any message arrived
- **WHEN** message consumption for a topic tab fails (for example a broker, authentication or decoding error) before any message was received
- **THEN** the message area SHALL show an error state with an error title, the failure cause and a "Retry" action
- **AND** it SHALL NOT show the "No messages loaded yet" card

#### Scenario: Consumption failure after some messages arrived
- **WHEN** message consumption fails after some messages were already received
- **THEN** the received messages SHALL remain visible
- **AND** an inline error notice with the cause and a "Retry" action SHALL be shown above them, so the partial result is not mistaken for a complete one

#### Scenario: Retrying a failed consumption
- **WHEN** the user activates "Retry" in the consumption error state
- **THEN** the system SHALL start the same read-only consumption with the current search configuration
- **AND** the error state SHALL be cleared when the new attempt starts

#### Scenario: Topic list fails to load
- **WHEN** loading the topic list of the active cluster fails
- **THEN** the explorer sidebar SHALL show an error state with the cause and a "Retry" action in place of the topic list
- **AND** it SHALL NOT show an empty topic list or a topic count of 0

#### Scenario: Retrying the topic list
- **WHEN** the user activates "Retry" in the topic list error state
- **THEN** the system SHALL reload the topic list with the same read-only metadata request and show the loading indicator while it runs

#### Scenario: Schema Registry subjects fail to load
- **WHEN** loading the Schema Registry subjects of a cluster with a configured Schema Registry fails
- **THEN** the explorer sidebar SHALL show an inline notice with the cause and a "Retry" action
- **AND** the schema inspector of a topic SHALL show the load error instead of stating that the topic has no schema

#### Scenario: Cluster without Schema Registry
- **WHEN** the active cluster has no Schema Registry configured
- **THEN** no subject load error SHALL be shown

#### Scenario: Localized error states
- **WHEN** the application runs under German or English locale
- **THEN** the error titles, notices and "Retry" labels SHALL be localized; the failure cause SHALL be shown as reported
