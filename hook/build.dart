import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

// Builds the rust/ bridge crate into the app bundle on Linux, macOS and Windows.
// Defaults are the flutter_rust_bridge ones: asset name src/rust/frb_generated.io.dart,
// crate dir rust/, release profile, routed to the app bundle.
void main(List<String> args) async {
  await build(args, (input, output) async {
    await FlutterRustBridgeNativeAssetsBuilder(
      extraCargoEnvironmentVariables: cargoEnvironment(
        input.config.code.targetOS,
        Platform.environment,
      ),
    ).run(input: input, output: output);
  });
}

/// Environment that cargo (and therefore its build scripts) needs to link the
/// native libraries behind librdkafka. `flutter build macos|windows` starts this
/// hook from Xcode or MSBuild, which do not carry the CI job's variables down to
/// cargo, so the values are handed over here instead.
Map<String, String> cargoEnvironment(
  OS targetOS,
  Map<String, String> environment, {
  bool Function(String path) directoryExists = _directoryExists,
}) {
  final env = <String, String>{
    // The vendored librdkafka CMakeLists asks for a CMake older than 3.5, which
    // the runners' CMake 4 rejects; this is CMake's own escape hatch. Linux
    // builds librdkafka with configure instead of CMake.
    if (targetOS == OS.macOS || targetOS == OS.windows)
      'CMAKE_POLICY_VERSION_MINIMUM': '3.5',
  };
  if (targetOS != OS.windows) return env;
  if (environment['OPENSSL_DIR'] != null) return env;

  // openssl-sys and sasl2-sys locate their libraries through vcpkg. PATH still
  // carries the vcpkg directory, so the root is taken from there.
  // shortcut: assumes host == target and vcpkg's default `installed\<triplet>`
  // layout; revisit when cross-compiling Windows or leaving vcpkg behind.
  String? vcpkgRoot;
  for (final candidate in [
    environment['VCPKG_ROOT'],
    environment['VCPKG_INSTALLATION_ROOT'],
    ...?environment['PATH']?.split(';'),
  ]) {
    if (candidate != null &&
        candidate.toLowerCase().split(RegExp(r'[\\/]')).last == 'vcpkg' &&
        directoryExists(candidate)) {
      vcpkgRoot = candidate;
      break;
    }
  }
  if (vcpkgRoot == null) return env;

  final installed = '$vcpkgRoot\\installed\\x64-windows';
  if (!directoryExists(installed)) return env;
  return {
    ...env,
    'VCPKG_ROOT': vcpkgRoot,
    'OPENSSL_DIR': installed,
    'OPENSSL_ROOT_DIR': installed,
    'SASL2_DIR': installed,
    'SASL2_LIB_DIR': '$installed\\lib',
    'SASL2_INCLUDE_DIR': '$installed\\include',
  };
}

bool _directoryExists(String path) => Directory(path).existsSync();
