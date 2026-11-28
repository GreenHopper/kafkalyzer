import 'package:code_assets/code_assets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../hook/build.dart';

void main() {
  const exists = true;

  test('macOS gets the CMake policy floor for vendored librdkafka', () {
    expect(
      cargoEnvironment(OS.macOS, const {
        'PATH': '/usr/bin',
      }, directoryExists: (_) => exists),
      {'CMAKE_POLICY_VERSION_MINIMUM': '3.5'},
    );
  });

  test('Linux needs nothing beyond the inherited environment', () {
    expect(
      cargoEnvironment(OS.linux, const {
        'PATH': '/usr/bin',
      }, directoryExists: (_) => exists),
      isEmpty,
    );
  });

  test('Windows finds vcpkg through PATH', () {
    final env = cargoEnvironment(OS.windows, const {
      'PATH': r'C:\Windows\system32;C:\vcpkg;C:\Program Files\CMake\bin',
    }, directoryExists: (_) => exists);
    expect(env['VCPKG_ROOT'], r'C:\vcpkg');
    expect(env['OPENSSL_DIR'], r'C:\vcpkg\installed\x64-windows');
    expect(env['SASL2_LIB_DIR'], r'C:\vcpkg\installed\x64-windows\lib');
    expect(env['CMAKE_POLICY_VERSION_MINIMUM'], '3.5');
  });

  test('a PATH entry without an installed tree is left alone', () {
    final env = cargoEnvironment(OS.windows, const {
      'PATH': r'C:\vcpkg',
    }, directoryExists: (path) => path != r'C:\vcpkg\installed\x64-windows');
    expect(env, {'CMAKE_POLICY_VERSION_MINIMUM': '3.5'});
  });

  test('an explicit OPENSSL_DIR wins over the PATH lookup', () {
    final env = cargoEnvironment(OS.windows, const {
      'PATH': r'C:\vcpkg',
      'OPENSSL_DIR': r'D:\openssl',
    }, directoryExists: (_) => exists);
    expect(env.containsKey('OPENSSL_DIR'), isFalse);
  });
}
