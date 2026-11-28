# Tasks

Prerequisite: none. The `flutter_secure_storage` 10.3.4 upgrade and the `EXCLUDED_ARCHS = x86_64` setting are already
committed on `spike/keyring-ci` and are carried by this change.

## 1. Spikes — before any version pin moves

- [x] 1.1 Add `rust/rust-toolchain.toml` with an exact channel (no bare `stable`) equal to the Rust version the CI jobs
      install, and `targets` = `aarch64-apple-darwin`, `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`,
      `x86_64-pc-windows-msvc`; verify `rustup show active-toolchain` in `rust/` reports that channel and
      `cargo test --manifest-path rust/Cargo.toml` still passes on the pinned toolchain
- [ ] 1.2 Add `hook/build.dart` in the velopack shape (`RustBuilder(cratePath: 'rust', assetName: 'src/lib.rs')`) plus
      `code_assets`/`hooks`/`native_toolchain_rust` in the root pubspec, **keeping** `rust_builder/` in place, and run
      the three platform builds on the branch; this is the cheap way to find out whether the explicit `--target` triple
      breaks the vendored `krb5-src`/OpenSSL builds before anything is deleted
- [ ] 1.3 If the macOS hook build fails on Kerberos, record the failing configure line in `design.md` and take fallback
      (a) pre-seed the krb5 configure cache variables, then (b) system GSSAPI instead of `gssapi-vendored`; escalate to
      the user before (c) dropping Kerberos SASL on macOS, because that removes a feature
- [ ] 1.4 Record the real hook `--target-dir` location from a Linux and a macOS build (`find .dart_tool build -type d
      -name target`) in the Open Questions section of `design.md`; the CI cache paths in task 4.3 come from this

## 2. Pins, integration, Cargokit removal

- [ ] 2.1 Install the matching generator: `cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked`
- [ ] 2.2 Raise `flutter_rust_bridge` to `2.13.0` in `pubspec.yaml`, `rust/Cargo.toml`,
      `rust/kafkalyzer-mcp/Cargo.toml` and `packages/velopack_flutter/pubspec.yaml`; re-apply the velopack patches
      documented in `KAFKALYZER_PATCHES.md`; `flutter pub get` must resolve a single version
- [ ] 2.3 Run `flutter_rust_bridge_codegen integrate --integration-backend native-assets`, then `generate`; commit the
      regenerated `lib/src/rust/frb_generated.dart` and `rust/src/frb_generated.rs` in the same commit as the wiring
- [ ] 2.4 Delete `rust_builder/` and its path dependency, drop the `rust_builder/**` exclusion in
      `analysis_options.yaml`, and confirm `rust_lib_kafkalyzer` is gone from
      `linux/flutter/generated_plugins.cmake`, `windows/flutter/generated_plugins.cmake` and
      `macos/Flutter/GeneratedPluginRegistrant.swift`
- [ ] 2.5 Green locally: `flutter analyze`, `flutter test`, `cargo test` in `rust/`, and `bash scripts/quality_gates.sh`
      including the bindings guard (pubspec pin == Cargo pin == installed codegen version)

## 3. Prove the build-path requirements on the development machine

- [ ] 3.1 From a clean checkout with only the documented bootstrap, `flutter build linux --release` produces a runnable
      app with no extra build command; start it and connect to a Kafka cluster so the bundled library is proven
- [ ] 3.2 Edit a Rust source under `rust/src/api`, re-run the debug app, and confirm the change is live without any
      codegen or wrapper build command in between
- [ ] 3.3 Introduce a deliberate compile error in the bridge crate and confirm `flutter build linux --release` fails
      with the cargo diagnostic (file and line) in the log; revert the error

## 4. CI

- [ ] 4.1 macOS job: replace `flutter config --no-enable-swift-package-manager` with the enabling flag and add the
      `ARCHS` assertion that fails the job with the resolved architectures named when they are not `arm64`
- [ ] 4.2 Verify in the macOS job log: no "unsupported for Swift Package Manager" warning, and
      `lipo -archs` on the built app binary reports `arm64` only
- [ ] 4.3 Replace the two Cargokit cache steps with per-job caching of the directory found in task 1.4, keyed by
      `os + flutter version + toolchain channel + sha256 of rust/Cargo.lock`; first migration run has caching off, the
      next run enables it and is timed against the 15-minute Windows budget
- [ ] 4.4 Remove the temporary Windows pre-build step (`cargo build --release -p rust_lib_kafkalyzer`) and confirm the
      Windows job builds and that a deliberately broken Rust file shows the cargo error in that job
- [ ] 4.5 Confirm the test job still passes unchanged: if `flutter test` now invokes the build hook, verify the native
      prerequisites it needs are already installed in that job
- [ ] 4.6 Prove the release-tag path without publishing: ask the user for approval, then either re-run the release
      workflow from a scratch tag that is deleted afterwards, or confirm the arch policy from the branch run; the
      macOS artifact set must contain exactly one arm64 build and the release notes must state arm64-only

## 5. Documentation and cleanup

- [ ] 5.1 Update the development docs: pinned Rust toolchain location, the new `hook/build.dart`, the codegen version
      to install, and the removal of `rust_builder/`
- [ ] 5.2 State the macOS arm64-only policy where users see it (README install section and release notes template) and
      update `KAFKALYZER_PATCHES.md` if the velopack patch set changed
