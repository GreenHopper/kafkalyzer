//! Argument parsing for `kafkalyzer-mcp` (design D8).

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Cli {
    /// Repeatable `--cluster` names; empty means all shared clusters.
    pub clusters: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CliAction {
    Run(Cli),
    Version,
    Help,
}

pub fn version_string() -> String {
    option_env!("KAFKALYZER_VERSION")
        .unwrap_or(env!("CARGO_PKG_VERSION"))
        .to_string()
}

pub fn help_text() -> String {
    format!(
        "kafkalyzer-mcp {ver}\n\n\
         Usage: kafkalyzer-mcp [--cluster <name>]... [--version] [--help]\n\n\
         Options:\n\
           --cluster <name>  Restrict tools to this shared cluster (repeatable)\n\
           --version, -V     Print version and exit\n\
           --help, -h        Print this help and exit\n",
        ver = version_string()
    )
}

/// Parse argv (without program name). Unknown flags → `Err` (exit code 2).
pub fn parse_args<I, S>(args: I) -> Result<CliAction, String>
where
    I: IntoIterator<Item = S>,
    S: AsRef<str>,
{
    let mut clusters = Vec::new();
    let mut iter = args.into_iter();
    while let Some(arg) = iter.next() {
        let arg = arg.as_ref();
        match arg {
            "--version" | "-V" => return Ok(CliAction::Version),
            "--help" | "-h" => return Ok(CliAction::Help),
            "--cluster" => {
                let name = iter
                    .next()
                    .ok_or_else(|| "missing value for --cluster".to_string())?;
                let name = name.as_ref().to_string();
                if name.is_empty() || name.starts_with('-') {
                    return Err(format!("invalid --cluster value '{name}'"));
                }
                clusters.push(name);
            }
            other if other.starts_with("--cluster=") => {
                let name = &other["--cluster=".len()..];
                if name.is_empty() {
                    return Err("missing value for --cluster".into());
                }
                clusters.push(name.to_string());
            }
            other => {
                return Err(format!("unknown argument: {other}"));
            }
        }
    }
    Ok(CliAction::Run(Cli { clusters }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_repeatable_cluster() {
        let action = parse_args(["--cluster", "a", "--cluster=b"]).unwrap();
        assert_eq!(
            action,
            CliAction::Run(Cli {
                clusters: vec!["a".into(), "b".into()],
            })
        );
    }

    #[test]
    fn unknown_is_error() {
        let err = parse_args(["--nope"]).unwrap_err();
        assert!(err.contains("unknown"));
    }

    #[test]
    fn version_and_help() {
        assert_eq!(parse_args(["--version"]).unwrap(), CliAction::Version);
        assert_eq!(parse_args(["-h"]).unwrap(), CliAction::Help);
    }
}
