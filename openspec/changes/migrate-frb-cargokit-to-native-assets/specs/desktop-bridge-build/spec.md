# Spec Delta

## Purpose
Describes how the desktop bridge library — the native code the Flutter frontend calls for Kafka work — becomes part of the packaged application on Linux, macOS, and Windows. It pins what a developer and CI may have to do to get that library built, where the library has to end up, and how a failure of that build has to surface.

## ADDED Requirements

### Requirement: Single Build Path For The Bridge Library
The build of the native bridge library SHALL be driven by the Flutter build itself, so that `flutter run`, `flutter test`, and every release build invoke the same build step. No additional manual build command, generated wrapper project, or per-platform plugin scaffold MAY be required to produce a working application build.

#### Scenario: Clean checkout produces a release build without extra steps
- **WHEN** a developer clones the repository, runs the documented bootstrap once, and runs a release build for Linux, macOS, or Windows
- **THEN** the native bridge library SHALL be compiled as part of that single build command
- **AND** the resulting application SHALL start and serve Kafka data without any further manual step

#### Scenario: Rust change is picked up by a development run
- **WHEN** a developer edits the Rust sources of the bridge crate and runs the app in debug mode again
- **THEN** the changed native code SHALL be recompiled and reflected in the running app
- **AND** no separate code-generation or wrapper-build command SHALL be needed for that

### Requirement: Build Failures Surface The Compiler Error
When the native bridge library fails to compile, the build SHALL fail with the underlying compiler or linker diagnostics visible in the build log, rather than with an opaque error from a build wrapper.

#### Scenario: Rust compile error breaks the platform build with a readable cause
- **WHEN** the native bridge library fails to compile during a Linux, macOS, or Windows build
- **THEN** the build SHALL fail
- **AND** the log SHALL contain the compiler or linker message that caused the failure, including the file and line where available

#### Scenario: Wrapper does not mask the cause
- **WHEN** the native build fails on a platform whose packaging tool invokes it indirectly
- **THEN** the reported failure SHALL name the failing native build step
- **AND** SHALL NOT be reduced to a generic tool exit code without the underlying message

### Requirement: Pinned Toolchain For Reproducible Native Builds
The toolchain version and build targets used to compile the native bridge library SHALL be declared in the repository, so that a developer machine and CI compile with the same toolchain without extra environment setup.

#### Scenario: Developer and CI use the declared toolchain
- **WHEN** a native build runs on a developer machine and in CI on the same commit
- **THEN** both SHALL use the toolchain version declared in the repository
- **AND** the build SHALL NOT depend on whichever toolchain happens to be the machine default

#### Scenario: Missing target on the machine
- **WHEN** the declared build target is not installed on the machine running the build
- **THEN** the build SHALL fail with a message naming the missing target
- **AND** SHALL NOT silently fall back to a different target

### Requirement: Bridge Library Bundled With Each Platform Artifact
The compiled native bridge library SHALL be packaged into the application artifact of each target platform, and the running application SHALL locate it without environment variables or manual installation.

#### Scenario: Packaged app finds its native library
- **WHEN** a packaged application artifact for Linux, macOS, or Windows is installed and started on the target platform
- **THEN** the application SHALL load the bundled native bridge library at startup
- **AND** the Kafka features backed by that library SHALL work without additional installation

#### Scenario: Library missing from the artifact
- **WHEN** the native bridge library is not present in the packaged artifact
- **THEN** the application SHALL fail to start its native layer with a diagnosable error
- **AND** the release pipeline SHALL treat the missing library as a build failure rather than shipping the artifact

### Requirement: Swift Package Manager Compatibility On macOS
With Swift Package Manager enabled for the macOS build, the dependency graph of the application SHALL contain no native dependency that is incompatible with it, and the build SHALL report no incompatibility warning for the bridge library.

#### Scenario: macOS release build with Swift Package Manager enabled
- **WHEN** the macOS release build runs with Swift Package Manager enabled
- **THEN** the build SHALL complete without an "unsupported for Swift Package Manager" warning for the bridge library or the secure storage plugin

#### Scenario: An incompatible dependency is reintroduced
- **WHEN** a reintroduced dependency does not support Swift Package Manager
- **THEN** the macOS build SHALL report that dependency by name in the warning output
- **AND** the pipeline SHALL keep the release artifact it produced marked as affected by that warning

### Requirement: Cached Native Build Output Without Stale Reuse
CI SHALL cache the native build output of the bridge library per platform so that repeated builds do not recompile unchanged dependencies, and a restored cache SHALL NOT cause changed Rust sources to be skipped.

#### Scenario: Warm cache speeds up a rebuild
- **WHEN** a platform build runs with a cache restored from an earlier build of the same lockfile and toolchain
- **THEN** unchanged native dependencies SHALL NOT be recompiled
- **AND** the platform build SHALL complete without rebuilding the whole dependency tree

#### Scenario: Cache miss still builds
- **WHEN** no cache entry exists for the platform build
- **THEN** the build SHALL succeed as a cold build
- **AND** SHALL create a cache entry for later builds

#### Scenario: Changed native source is rebuilt
- **WHEN** a commit changes Rust sources of the bridge crate and a cache entry from the previous commit is restored
- **THEN** the changed crate SHALL be recompiled
- **AND** the produced artifact SHALL contain the changed native code
