# explorer-onboarding Specification Delta

## Purpose

Provides guided onboarding and actionable empty states across the Explorer workflow, enabling zero-friction cluster connection, instant cluster overview visibility, and 1-click message fetching when topic tabs contain no messages.

## ADDED Requirements

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

---

### Requirement: Cluster Overview Dashboard Empty State

When a cluster is actively selected but no topic tab is open in the Explorer view, the main content area SHALL display an informative cluster overview showing cluster connection metadata, total topic count, Schema Registry status, and quick access to recently viewed topics for that cluster.

#### Scenario: Displaying cluster overview metrics
- **WHEN** an active cluster connection is established and all topic tabs are closed
- **THEN** the Explorer main content area SHALL display the cluster name, bootstrap server address, total number of topics, and Schema Registry configuration indicator
- **AND** display quick-launch cards or list items for recently opened topics belonging to this cluster

#### Scenario: Opening a recent topic from the cluster overview
- **WHEN** the user clicks on a recent topic card in the cluster overview
- **THEN** the system SHALL open a new search tab for that topic and focus it

---

### Requirement: Actionable Empty State in Topic Message View

When a topic tab is open with zero loaded messages and message consumption is inactive (`isStreaming = false`), the message area SHALL display an actionable empty state card with a primary action button to fetch messages immediately using the current configuration, and a helpful tip indicating that double-clicking topics in the sidebar starts fetching automatically.

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
