# velopack_flutter

[![pub package](https://img.shields.io/pub/v/velopack_flutter.svg)](https://pub.dartlang.org/packages/velopack_flutter)

A Flutter implementation of Velopack using flutter_rust_bridge for automated desktop app updates.

## Why Velopack?

Flutter currently lacks a robust solution for distributing auto-updates for desktop applications, aside from the Microsoft and Mac App Stores. Velopack addresses this gap by providing a cross-platform installation and auto-update framework for desktop applications.

Learn more about Velopack at [https://velopack.io/](https://velopack.io/)

This project leverages [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) to interface with the Rust implementation of Velopack.

## Getting Started

1. Make sure Rust is installed: <https://www.rust-lang.org/tools/install>
2. Add the velopack_flutter dependency to your `pubspec.yaml`:

```yaml
  dependencies:
    velopack_flutter: ^0.2.0
```

3. Import the package, initialize Velopack and handle Velopack app hooks in your main.dart:

```dart
import 'package:flutter/material.dart';
import 'package:velopack_flutter/velopack_flutter.dart';

Future<void> main(List<String> args) async {
  await initializeVelopack(url: 'https://example.com/releases');

  final veloCommands = ['--veloapp-install', '--veloapp-updated', '--veloapp-obsolete', '--veloapp-uninstall'];
  if (veloCommands.any((cmd) => args.contains(cmd))) {
    exit(0);
  }

  /* You can now call the API functions shown in the API section. E.g isUpdateAvailable();
     Do note that the API functions will only function correctly in a vpk packed release.
     isUpdateAvailable and the rest will just throw an exception if you call them while debugging.
  */
  runApp(const MyApp());
}
```

## Use with another Rust library

If your project has existing Rust bindings, you'll need to have a distinct library class name to prevent name conflicts.

This is what Velopack Flutter is doing by setting the following values in `flutter_rust_bridge.yaml` to make the class name "unique" and avoid conflicts.

```yaml
  dart_entrypoint_class_name: VelopackRustLib
```

**We recommend you do the same on your own Rust bindings.**

## API

| Function | Description                                                                                                                  |
|----------|--------------------------------------------------------------|
| `initializeVelopack({required String url, String? channel, bool allowDowngrade = false})` | Initializes the bridge and configures Velopack with the update server URL. Optionally overrides the update `channel` and allows downgrades (see [Channels](#channels)). |
| `isUpdateAvailable({String? channel, bool? allowDowngrade})` | Checks if an update is available. Pass `channel` / `allowDowngrade` to check a different channel for this call only (see [Channels](#channels)). |
| `getLatestUpdateInfo({String? channel, bool? allowDowngrade})` | Gets detailed information about the latest available update. Pass `channel` / `allowDowngrade` to query a different channel for this call only. |
| `currentVersion()` | Returns the current application version as a string.                                                  |
| `checkAndDownloadUpdatesWithProgress({String? channel, bool? allowDowngrade})` | Checks for updates, downloads them, and returns a progress stream. Pass `channel` / `allowDowngrade` to target a different channel for this call only. |
| `updateAndRestart({String? channel, bool? allowDowngrade})` | Applies downloaded updates and restarts the application. Pass `channel` / `allowDowngrade` to target a different channel for this call only. |
| `updateAndExit({String? channel, bool? allowDowngrade})` | Applies downloaded updates and exits the application. Pass `channel` / `allowDowngrade` to target a different channel for this call only. |
| `waitExitThenUpdate({required bool silent, required bool restart, String? channel, bool? allowDowngrade})` | Waits for the app to exit, then applies updates. If `restart` is true, the app will restart after applying updates. Use `silent` to suppress UI messages. Pass `channel` / `allowDowngrade` to target a different channel for this call only. |

## Channels

Velopack supports release channels (e.g. `staging`, `prod`), set when packaging with `vpk pack ... --channel <name>`. By default an installed app keeps receiving updates from the channel it was installed from — no extra code needed.

To make the app follow a different channel, pass it to `initializeVelopack`:

```dart
await initializeVelopack(
  url: 'https://example.com/releases',
  channel: 'prod',
);
```

The channel passed to `initializeVelopack` is the default for every call. To check or pull from a different channel without changing that default, pass `channel` to an individual function:

```dart
// Peek at what's on the beta channel while staying on the default channel
final beta = await getLatestUpdateInfo(channel: 'beta');

// Switch over by downloading and applying from beta
await updateAndRestart(channel: 'beta');
```

A per-call `channel` overrides the init default for that call only; omit it to use the init default (or the install channel when none was set).

The init-level default channel is read once at initialization, so changing *that* default takes effect on the **next launch**. Persist the user's selected channel (e.g. with `shared_preferences`), then restart the app to apply it.

### Downgrades

Switching to a channel whose latest version is **older** than the installed version is a downgrade. Velopack ignores downgrades unless you opt in. You can opt in globally at init:

```dart
await initializeVelopack(
  url: 'https://example.com/releases',
  channel: 'prod',        // e.g. prod is 1.0.0 while the app is on staging 1.1.0
  allowDowngrade: true,   // required, otherwise no update is offered
);
```

…or per call, which overrides the init default for that call only. This pairs with the per-call `channel` so you can preview and switch to an older channel without re-initializing or restarting:

```dart
// Preview with the same condition the apply will use
final info = await getLatestUpdateInfo(channel: 'prod', allowDowngrade: true);

// Switch to prod and accept the downgrade, just for this call
await updateAndRestart(channel: 'prod', allowDowngrade: true);
```

When `allowDowngrade` is omitted on a call, the init default is used.

## Packaging

1. Install .NET Core SDK 6.0 and the `vpk` tool:

```shell
dotnet tool update -g vpk
```

2. Build your Flutter app:

```shell
flutter build [windows|macos|linux] --release
```

3. Navigate to your release build directory & package your app using `vpk`:

### Windows

```shell
cd build/windows/x64/runner
vpk pack --packId YourAppId --packVersion 1.0.0 --packDir Release --mainExe YourApp.exe
```

### macOS

```shell
cd build/macos/Build/Products/Release
vpk pack -u "xyz.appName.companyName" -v 1.0.0 \
            -p "./YourApp.app" \
            --channel "osx-channelName" \
            --mainExe "Application Binary" \
            --noPortable --packTitle "Application Title" --signEntitlements "$(pwd)/macos/Runner/Release.entitlements" \
            --signAppIdentity "Developer ID Application: (Your Name)" \
            --signInstallIdentity "Developer ID Installer: (Your Name)" \
            --notaryProfile "notary-profile-name" \
```


Your release package will be generated in the `Releases` directory.

For more information on packaging and distribution, refer to:

- [Velopack Packaging Documentation](https://docs.velopack.io/category/packaging)
- [Velopack Distribution Documentation](https://docs.velopack.io/category/distributing)

## Using GitHub releases as your updates location

There is an issue (<https://github.com/velopack/velopack/issues/254>) in the Velopack repo about adding full API support for GitHub releases. In the meantime
you can still use GitHub releases with a few workarounds:

### Download step (before packing the release)

Run the download command before packing to include the latest information from your GitHub releases

```shell
vpk download github --repoUrl https://github.com/{orgOrUser}/{repoName}
```

Then pack as normal.

#### Uploading

```shell
vpk upload github --repoUrl https://github.com/{orgOrUser}/{repoName} --publish --releaseName YourDesiredReleaseName --tag v1.0.0 --token your_github_token
```

#### Using the API in your Flutter app

Velopack expects all the files to be available at the given URL. One way to accomplish this with GitHub releases is
to specify `${repoUrl}releases/download/${tagName}/` as the URL passed to `initializeVelopack`.
This does require you to parse out the tag for the latest release manually yourself, e.g.:  

```dart
final url = Uri.parse('${repoUrl}releases/latest/');
final response = await http.get(url);
if (response.statusCode == 200) {
  final data = json.decode(response.body);
  final tag_name = data['tag_name']
}
```

## Notes

- The Linux implementation is currently untested. Contributions and feedback from Linux users are welcome.
- The API may differ from Velopack implementations in other languages and is not feature-complete. In the long-term it would make sense to keep these consistent, however I didn't have time for this yet. Feel free to open a PR!

## Contributing

If you encounter issues, have suggestions, or want to contribute code, please open an issue or submit a pull request on this GitHub repository.
