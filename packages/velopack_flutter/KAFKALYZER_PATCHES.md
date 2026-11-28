# Patched kafkalyzer vendor of velopack_flutter
# - AutoSource for GitHub Releases
# - Flutter 3.44+ code-assets hook guard
# - Start progress forwarding thread before download_updates (real-time progress)
# - VelopackApp::build().set_auto_apply_on_startup(false) (explicit user confirmation & cancel safety)
# - flutter_rust_bridge 2.13.0 with regenerated lib/src/rust bindings (kafkalyzer pin)
# - code_assets/hooks/native_toolchain_rust raised to 2.x, matching the app (flutter_rust_bridge_hooks needs 2.x)
# - rust/rust-toolchain.toml pinned (same channel as kafkalyzer/rust, so one rustup install serves both)
