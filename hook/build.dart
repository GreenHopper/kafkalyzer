import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

// Builds the rust/ bridge crate into the app bundle on Linux, macOS and Windows.
// Defaults are the flutter_rust_bridge ones: asset name src/rust/frb_generated.io.dart,
// crate dir rust/, release profile, routed to the app bundle.
void main(List<String> args) async {
  await build(args, (input, output) async {
    await const FlutterRustBridgeNativeAssetsBuilder()
        .run(input: input, output: output);
  });
}
