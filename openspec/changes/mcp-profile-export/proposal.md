# Proposal

Roadmap entry: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.16 `mcp-profile-export` (Phase 4,
decisions E3, E4, E18).

## Why

A coding agent can only use kafkalyzer's analysis functions through a process that runs without the GUI
(`kafkalyzer-mcp`, change `mcp-stdio-server`). That process cannot read the app's profile store: profiles live in
`shared_preferences` and secrets in `flutter_secure_storage`, both in plugin-specific formats per platform (roadmap
§2.3 no. 8). Without an explicit, per-cluster hand-over there is also no allowlist, and every configured cluster —
including production — would be reachable by an agent that forwards payloads to an LLM provider.

## What Changes

- Each cluster profile gets a "share with MCP" setting, off by default, switched in a dialog that names the data
  flow to the LLM provider before the user enables it.
- Shared profiles are written without secrets to one file in the user's configuration directory; their secrets go
  to the OS keyring under a service name of their own, separate from the app's entries (E4). This set of shared
  profiles is the allowlist for every headless Rust binary.
- Every profile save (edit, rename, delete, import, switching the setting off) updates the file and the keyring
  entries in the same step. A failed update is reported and never leaves a profile shared without its secrets.
- The dialog offers a copyable MCP client configuration snippet that starts `kafkalyzer-mcp` for that one profile.
- Sharing is a decision per machine: importing or duplicating a profile never turns sharing on.
- A shared profile is marked in the cluster list (icon plus text).

How: a new sibling crate `kafkalyzer-profiles` owns the file format and the keyring access, so the app writes and
the headless binary reads with the same code. The bridge exposes one sync function; `ClusterService.saveClusters`
is the single call site.

Read-only impact: **no new Kafka or Schema Registry calls.** `scripts/check_read_only.sh` passes unchanged; the new
crate declares neither `rdkafka`, `reqwest` nor `flutter_rust_bridge`.

Prerequisites: none (5.1 `harden-read-only-gate` and 5.22 `harden-local-storage-and-imports` are archived).

Non-goals:

- The MCP server itself and its tools (`mcp-stdio-server`, §5.17).
- A listener or server process inside the GUI (E3).
- Secret references to environment variables for CI and containers (follow-up named in §5.39, shares E4).
- Using the shared profiles for the headless script runner (`kafkalyzer --script` keeps reading the app store, E19).
- Moving the app's own secrets from `flutter_secure_storage` to the Rust keyring crate.
- Writing into any MCP client's configuration file; the snippet is copy-only.

## Capabilities

### New Capabilities

- `headless-profile-export`: per-profile sharing of cluster connections with headless binaries — the opt-in
  setting, the secret-free shared file, the dedicated keyring entries, keeping both in step with profile changes,
  and the MCP client configuration snippet.

### Modified Capabilities

None. `secure-credentials-storage` and `cluster-profile-persistence` already require what the app store does; the
shared copy is additional and specified in the new capability.

## Impact

- Rust: new crate `rust/kafkalyzer-profiles` (workspace member; depends on `kafkalyzer-core`, `serde`,
  `serde_json`, `anyhow`, `log`, and the new dependency `keyring`). `rust/Cargo.toml` gains the member and the
  dependency.
- Bridge: `ClusterProfile` DTO gains one optional field (stored JSON stays readable); new file
  `rust/src/api/headless_profiles.rs` with one sync function. Regenerated `lib/src/rust/`,
  `rust/src/frb_generated.rs`, `test/src/rust/api/rust_mocks.mocks.dart`.
- Dart: `lib/src/services/cluster_service.dart` (sync after save, field pass-through in `sanitized`,
  `withSecrets`, `copyWith`, reset on import), `cluster_list_controller.dart`, new dialog under
  `lib/src/features/cluster/presentation/widgets/`, `settings_cluster_section.dart` (row action and badge),
  `app_en.arb` / `app_de.arb`.
- Build: Linux needs a Secret Service at run time for sharing (already true for the app's own secrets);
  `snap/snapcraft.yaml` is not changed.
- Docs: `README.md` section on sharing a cluster with an MCP client.
