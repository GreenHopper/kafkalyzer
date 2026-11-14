# Tasks

## 1. Source pattern checks

- [x] 1.1 In `scripts/check_read_only.sh`, add a `SCOPE` field (`all`|`rs`) to the check table, build the `*.rs`
  subset of the scan list, and mark existing rows `all`; verify `bash scripts/check_read_only.sh` still exits 0 with
  the same 5 checks passing and `bash scripts/test_check_read_only.sh` still passes 10/10.
- [x] 1.2 Add the rows "Mutating admin calls" and "Offset store" (scope `all`, no exclude) with the design D2 regexes;
  in `scripts/test_check_read_only.sh` add rejected cases (`admin.create_topics(&t, &o)`,
  `admin.incremental_alter_configs(&c)`, `admin.delete_groups (&g, &o)`, `c.store_offsets(&tpl)`,
  `c.store_offset_from_message(&m)`, and `admin.delete_topics(&t, &o); // allow_read_only_exception: x`) and accepted
  cases (`admin.describe_configs(&r, &o)`, `consumer.committed_offsets(tpl, t)`, `fn my_delete_topics_view()`);
  verify the test script passes.
- [x] 1.3 Add the rows "HTTP PUT/DELETE/PATCH" (scope `rs`, no exclude) and "HTTP POST" (scope `rs`, exclude
  `allow_read_only_exception:[[:space:]]*[^[:space:]]`); add rejected cases (`client.put(url)`, `client.delete(url)`,
  `client.patch (url)`, `client.request(Method::DELETE, url)`, unmarked `client.post(url)`, and
  `client.post(url) // allow_read_only_exception`) and accepted cases (`client.post(url) // allow_read_only_exception:
  compatibility check`, `client.get(url)`, and a Dart file `lib/src/s.dart` with `await _storage.delete(key: key);`);
  verify the test script passes.
- [x] 1.4 Add the reasoned marker to `rust/kafkalyzer-kafka/src/schema_registry.rs:301`:
  `.post(endpoint) // allow_read_only_exception: Schema Registry compatibility check, stores nothing` (comment only);
  verify `bash scripts/check_read_only.sh` exits 0 and `cargo fmt --all --check` (in `rust/`) reports no diff.
- [x] 1.5 Add the row "Native mutating calls" (scope `rs`, no exclude) with the regex
  `rd_kafka_(produce|producev|produceva|produce_batch|send_offsets_to_transaction|commit|commit_message|commit_queue|offset_store|offsets_store|subscribe|CreateTopics|DeleteTopics|CreatePartitions|AlterConfigs|IncrementalAlterConfigs|DeleteRecords|DeleteGroups|DeleteConsumerGroupOffsets|AlterConsumerGroupOffsets|CreateAcls|DeleteAcls|AlterUserScramCredentials)[^A-Za-z_]`
  (guards a possible FFI binding from `fix-consumer-lag-accuracy`, spike candidate A); add rejected cases
  (`rd_kafka_commit(rk, ptr::null(), 0)`, `rd_kafka_AlterConsumerGroupOffsets(rk, o, 1, opts, q)`,
  `rd_kafka_offsets_store(rk, tpl)`) and accepted cases (`rd_kafka_ListConsumerGroupOffsets(rk, r, 1, opts, q)`,
  `rd_kafka_DescribeConsumerGroups(rk, g, 1, opts, q)`); verify the pattern has 0 hits on today's `rust/` and the
  test script passes.
- [x] 1.6 Add accepted cases for existing rows (`config.set("enable.auto.commit", "false");`,
  `consumer.assign(&tpl)?;`) and update the final case-count message; verify the test script passes.

## 2. Crate dependency allowlist

- [x] 2.1 Add the manifest block to `scripts/check_read_only.sh` (design D5): walk `Cargo.toml` under
  `$TARGET_ROOT/rust` (prune `target/`), flag `rdkafka|rdkafka-sys|reqwest` outside
  `rust/kafkalyzer-kafka/Cargo.toml` and `flutter_rust_bridge` outside `rust/Cargo.toml`, report path:line, add to
  the violation total; verify `bash scripts/check_read_only.sh` exits 0 on the repo (3 manifests, no violation).
- [x] 2.2 In `scripts/test_check_read_only.sh` add manifest cases in the temp tree: rejected
  `rust/kafkalyzer-core/Cargo.toml` with `rdkafka = "0.36"`, with `[dependencies.reqwest]`, with
  `kafka = { package = "rdkafka", version = "0.36" }`, and with `flutter_rust_bridge = "=2.11.1"`; accepted
  `rust/kafkalyzer-kafka/Cargo.toml` with `rdkafka`/`reqwest` in a `[target.'cfg(target_os = "linux")'.dependencies]`
  section and `rust/Cargo.toml` with `flutter_rust_bridge`; remove each fixture after its case; verify the test
  script passes.

## 3. CI and repository cleanup

- [x] 3.1 In `.github/workflows/build.yml` job `read-only-gate`, add a step `bash scripts/test_check_read_only.sh`
  after the gate step; verify the YAML parses (`python3 -c "import yaml,sys;
  yaml.safe_load(open('.github/workflows/build.yml'))"`) and the job still has no toolchain setup.
- [x] 3.2 Delete `.insecure_curlrc` (`git rm .insecure_curlrc`); verify `git grep -n insecure_curlrc -- ':!design'`
  finds nothing and `git ls-files .insecure_curlrc` is empty.

## 4. Verification

- [ ] 4.1 Run `bash scripts/test_check_read_only.sh` (all cases pass, exit 0), `bash scripts/check_read_only.sh`
  (all checks PASSED, exit 0), and in `rust/`: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets`,
  `cargo test --workspace` (all green). No Dart file changes, so `flutter analyze`/`flutter test` are not required;
  confirm with `git diff --stat` that only the files listed in `proposal.md` Impact changed.

## Workflow follow-up

- Archive the change after review; the archive merges the delta into
  `openspec/specs/read-only-invariants-enforcement/spec.md`.
