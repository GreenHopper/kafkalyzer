# Proposal

## Why

kafkalyzer's core identity and critical selling point in enterprise environments is that it is strictly read-only, eliminating the risk of accidental production mutations or poison pill publications. However, this guarantee is currently maintained only by informal developer convention rather than automated CI enforcement, and lacks explicit documentation or in-app guidance for configuring least-privilege Kafka service accounts.

## What Changes

- **CI Gate Against Write Paths (C1)**: Introduce a dedicated verification script (`scripts/check_read_only.sh`) and automated GitHub Actions CI job in `.github/workflows/build.yml` that scans the Rust (`rust/*/src`) and Dart (`lib/src`) codebases for forbidden producer and mutation APIs (`Producer`, `ThreadedProducer`, `FutureRecord`, `.send(`, `subscribe(`, and manual/automatic `commit`), failing builds immediately upon detection.
- **Documented Read-Only Invariants (C2)**: Add a prominent "Read-Only by Design" section to `README.md` detailing architectural invariants (exclusive use of `BaseConsumer`, explicit assignment without group coordination, `enable.auto.commit=false`, and read-only metadata calls), and surface an in-app read-only badge and security note in the Cluster Configuration Dialog and Settings.
- **Least-Privilege Service Account Recommendations (C3)**: Provide clear in-app guidance and documentation for security teams and cluster administrators recommending dedicated read-only service accounts with ACLs strictly limited to `Describe`, `Read`, and `DescribeConfigs` on topics and cluster resources, explicitly forbidding `Write`, `AlterConfigs`, and `IdempotentWrite`.

## Capabilities

### New Capabilities

- `read-only-invariants-enforcement`: Automated CI gate and verification tooling that scans and strictly enforces read-only codebase guarantees, preventing Kafka producer clients, message publishing, and offset mutations.
- `read-only-security-guidance`: In-app security notices, cluster configuration guidance, and architectural documentation for read-only invariants and least-privilege Kafka service account ACLs.

### Modified Capabilities

<!-- None: Existing capabilities remain functionally unchanged. -->

## Impact

- **Tooling & CI**: New shell script `scripts/check_read_only.sh` and added job in `.github/workflows/build.yml`.
- **Documentation**: Comprehensive "Read-Only by Design" section and ACL guidance in `README.md`.
- **UI Components**: Enhanced `ClusterConfigDialog` and `SettingsView` with subtle read-only trust indicators and recommended ACL guidance dialog/popover.
- **Localization**: Added translation strings in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
