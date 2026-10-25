# Design

## Context

kafkalyzer connects directly to Apache Kafka clusters, which often reside in sensitive staging and production environments containing mission-critical event streams. While the architecture was built exclusively with `BaseConsumer` and explicit partition assignments without offset commits (`enable.auto.commit=false`), there was previously no CI-enforced static analysis gate preventing a developer from accidentally importing `rdkafka::producer` or calling offset commits. Furthermore, users and enterprise security reviewers had no in-app documentation or ACL templates demonstrating how to enforce read-only isolation on the broker itself.

## Goals / Non-Goals

**Goals:**
- Provide a fast, standalone static analysis script (`scripts/check_read_only.sh`) that checks the Rust and Dart source trees for any prohibited Kafka producer, publish, subscribe, or commit APIs.
- Integrate the check into `.github/workflows/build.yml` as a fast-failing prerequisite job on pull requests and branch builds.
- Enhance `ClusterConfigDialog` and `SettingsView` with a subtle read-only trust badge and an interactive "Recommended Read-Only ACLs" guidance dialog.
- Document architectural invariants and least-privilege broker setup instructions in `README.md`.

**Non-Goals:**
- Supporting write operations, message publishing, poison-pill re-injection, or DLQ redelivery inside kafkalyzer (external tools like `kcat` remain recommended for reprocessing).
- Modifying broker ACLs from the client (kafkalyzer will never contain admin write or ACL mutation APIs).

## Decisions

### 1. Static Grep-Based Verification Script vs. Custom Linter

- **Choice**: Implement a standalone POSIX bash script (`scripts/check_read_only.sh`) using regex pattern matching with ripgrep/grep.
- **Rationale**: A shell script executes in sub-second time, requires zero extra build dependencies in CI or local developer machines, and directly pinpoints file and line numbers of any forbidden tokens.
- **Forbidden Patterns**:
  - `Producer`, `ThreadedProducer`, `BaseProducer`, `FutureProducer`, `FutureRecord`
  - `.send(` on Kafka client handles
  - `.commit(`, `.commit_message(`, `.commit_consumer_state(`
  - `\.subscribe\(` (ensuring consumer group dynamic rebalancing/heartbeating is never enabled in favor of manual partition assignment)
- **Alternatives Considered**: Writing a custom Rust `clippy` plugin or AST parser. Rejected due to excessive build overhead and maintenance complexity for a simple invariant check.

### 2. CI Pipeline Fast-Fail Gate

- **Choice**: Add a dedicated `read-only-gate` job in `.github/workflows/build.yml` before long-running compilation matrix builds.
- **Rationale**: Prevents wasting runner minutes on cross-compilation (macOS, Windows, Linux) if a read-only guarantee is broken.

### 3. Progressive In-App Security Disclosure & Dialog

- **Choice**: Add an unobtrusive `ReadOnlySecurityBadge` in `ClusterConfigDialog` and `SettingsView` with a clickable information button opening `ReadOnlyGuidanceDialog`.
- **Rationale**: Keeps the form uncluttered for everyday users while giving security engineers immediate access to least-privilege Kafka ACL commands (`kafka-acls.sh`) and architectural guarantees.
- **UI Elements**: Uses `package:material_ui/material_ui.dart` adhering to existing project UI standards.

## Risks / Trade-offs

- **[Risk] False positives on unrelated comments or methods named `.send(`** → **Mitigation**: Scope the regex patterns to match Kafka client and producer types, and allow explicit whitelist annotations (e.g., `# [allow_read_only_exception]`) only if strictly necessary for non-Kafka utility functions.
- **[Risk] Broker configurations that permit writes if credentials are misconfigured** → **Mitigation**: Surface explicit Kafka ACL configuration templates in the app so cluster admins enforce read-only permissions directly at the broker boundary (defense-in-depth).
