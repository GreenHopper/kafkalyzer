# main-navigation Specification

## Purpose

Defines the app's top-level navigation surface — which views are exposed in the main navigation rail and where search functionality lives — so that the UI presents a single, consistent entry point per capability without duplicating search in a standalone destination.

## Requirements

### Requirement: Main Navigation Destinations

The main navigation rail SHALL expose exactly the following destinations, in this order:

1. Explorer
2. Consumer Lag
3. Scripts
4. Settings

The rail MUST NOT expose a dedicated "Multi-Search" destination. Selecting any destination SHALL switch the main content area to that view, with Explorer as the default view on launch.

#### Scenario: Navigation rail destinations

- **WHEN** the user opens the application
- **THEN** the navigation rail SHALL display exactly the Explorer, Consumer Lag, Scripts, and Settings destinations in that order, and SHALL NOT display a dedicated "Multi-Search" destination

#### Scenario: Switching between destinations

- **WHEN** the user selects a navigation destination
- **THEN** the main content area SHALL switch to the corresponding view, and the previously selected destination SHALL become unselected

#### Scenario: Default view on launch

- **WHEN** the application starts
- **THEN** the main content area SHALL display the Explorer view by default

### Requirement: Search Available Through Explorer

Cross-topic / multi-topic search functionality SHALL remain available to the user through the Explorer view, using the shared search configuration (start/end conditions) and the shared search engine. Removing the dedicated Multi-Search destination MUST NOT remove the ability to run searches, inspect search results, or run scripted searches.

#### Scenario: Running a search from Explorer

- **WHEN** the user initiates a search via the Explorer view
- **THEN** the system SHALL start the search using the shared search engine and make the results available for inspection

#### Scenario: Scripted searches unaffected

- **WHEN** the user runs a script that performs searches
- **THEN** the system SHALL execute those searches using the shared search engine, independent of the removed Multi-Search UI

### Requirement: Shared Search Infrastructure Retained

The shared search infrastructure — the search controller, the search JSON serializer, and the shared start/end condition and topic selection configuration widgets — SHALL remain intact and functional so that the Explorer view and the scripting feature continue to work without behavior change.

#### Scenario: Explorer uses shared search configuration

- **WHEN** the user configures a search in the Explorer view
- **THEN** the system SHALL render the shared start/end condition and topic selection widgets and drive the shared search controller

#### Scenario: Settings directory loading unaffected

- **WHEN** the user interacts with settings that load the search output directory
- **THEN** the system SHALL resolve the directory through the shared search controller without error
