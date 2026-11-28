use std::path::PathBuf;

use anyhow::{bail, Result};

/// Resolves `<config dir>/kafkalyzer/shared-profiles.json` using `env` for lookups.
///
/// | Platform | Config dir |
/// |---|---|
/// | Linux | `$XDG_CONFIG_HOME` if set and absolute, else `$HOME/.config` |
/// | macOS | `$HOME/Library/Application Support` |
/// | Windows | `%APPDATA%` |
pub fn default_path_with_env(env: &dyn Fn(&str) -> Option<String>) -> Result<PathBuf> {
    let config_dir = config_dir_with_env(env)?;
    Ok(config_dir.join("kafkalyzer").join("shared-profiles.json"))
}

/// Same as [`default_path_with_env`] using [`std::env::var`].
pub fn default_path() -> Result<PathBuf> {
    default_path_with_env(&|key| std::env::var(key).ok())
}

fn config_dir_with_env(env: &dyn Fn(&str) -> Option<String>) -> Result<PathBuf> {
    #[cfg(target_os = "linux")]
    {
        if let Some(xdg) = env("XDG_CONFIG_HOME") {
            let path = PathBuf::from(&xdg);
            if path.is_absolute() {
                return Ok(path);
            }
        }
        match env("HOME") {
            Some(home) if !home.is_empty() => Ok(PathBuf::from(home).join(".config")),
            _ => bail!("configuration directory unknown"),
        }
    }

    #[cfg(target_os = "macos")]
    {
        match env("HOME") {
            Some(home) if !home.is_empty() => Ok(PathBuf::from(home)
                .join("Library")
                .join("Application Support")),
            _ => bail!("configuration directory unknown"),
        }
    }

    #[cfg(target_os = "windows")]
    {
        match env("APPDATA") {
            Some(appdata) if !appdata.is_empty() => Ok(PathBuf::from(appdata)),
            _ => bail!("configuration directory unknown"),
        }
    }

    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    {
        let _ = env;
        bail!("configuration directory unknown");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use std::path::Path;

    fn lookup(map: HashMap<&'static str, &'static str>) -> impl Fn(&str) -> Option<String> {
        move |key| map.get(key).map(|v| (*v).to_string())
    }

    #[test]
    #[cfg(target_os = "linux")]
    fn linux_uses_xdg_config_home_when_absolute() {
        let env = lookup(HashMap::from([
            ("XDG_CONFIG_HOME", "/custom/config"),
            ("HOME", "/home/user"),
        ]));
        assert_eq!(
            default_path_with_env(&env).unwrap(),
            Path::new("/custom/config/kafkalyzer/shared-profiles.json")
        );
    }

    #[test]
    #[cfg(target_os = "linux")]
    fn linux_falls_back_to_home_config_without_xdg() {
        let env = lookup(HashMap::from([("HOME", "/home/user")]));
        assert_eq!(
            default_path_with_env(&env).unwrap(),
            Path::new("/home/user/.config/kafkalyzer/shared-profiles.json")
        );
    }

    #[test]
    #[cfg(target_os = "linux")]
    fn linux_ignores_relative_xdg_config_home() {
        let env = lookup(HashMap::from([
            ("XDG_CONFIG_HOME", "relative/config"),
            ("HOME", "/home/user"),
        ]));
        assert_eq!(
            default_path_with_env(&env).unwrap(),
            Path::new("/home/user/.config/kafkalyzer/shared-profiles.json")
        );
    }

    #[test]
    #[cfg(target_os = "macos")]
    fn macos_uses_application_support() {
        let env = lookup(HashMap::from([("HOME", "/Users/me")]));
        assert_eq!(
            default_path_with_env(&env).unwrap(),
            Path::new("/Users/me/Library/Application Support/kafkalyzer/shared-profiles.json")
        );
    }

    #[test]
    #[cfg(target_os = "windows")]
    fn windows_uses_appdata() {
        let env = lookup(HashMap::from([("APPDATA", r"C:\Users\me\AppData\Roaming")]));
        assert_eq!(
            default_path_with_env(&env).unwrap(),
            Path::new(r"C:\Users\me\AppData\Roaming\kafkalyzer\shared-profiles.json")
        );
    }

    #[test]
    fn directory_unknown_is_an_error() {
        let env = lookup(HashMap::new());
        let err = default_path_with_env(&env).unwrap_err();
        assert!(
            err.to_string().contains("configuration directory unknown"),
            "unexpected error: {err}"
        );
    }
}
