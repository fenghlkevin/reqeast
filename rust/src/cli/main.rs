mod checks;
mod config;
mod dataset;
mod project;
mod run;
mod variables;

use std::{collections::BTreeMap, path::PathBuf};

pub type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

pub struct Options {
  root: PathBuf,
  workflow: String,
  environment: Option<String>,
  data: Option<PathBuf>,
  secrets: Option<PathBuf>,
  report: Option<PathBuf>,
}

fn options(args: &[String]) -> Result<Options> {
  if args.len() < 2 || args[0] != "run" {
    return Err("Usage: reqeast-cli run PROJECT --workflow NAME [--environment NAME] [--data CSV|JSON] [--secrets JSON] [--report JSON]".into());
  }
  let mut flags = BTreeMap::new();
  let (pairs, remainder) = args[2..].as_chunks::<2>();
  for pair in pairs {
    if !["--workflow", "--environment", "--data", "--secrets", "--report"].contains(&pair[0].as_str())
      || flags.insert(pair[0].clone(), pair[1].clone()).is_some()
    {
      return Err("Unknown or duplicate option".into());
    }
  }
  if !remainder.is_empty() {
    return Err("Missing option value".into());
  }
  Ok(Options {
    root: PathBuf::from(&args[1]),
    workflow: flags.remove("--workflow").ok_or("--workflow is required")?,
    environment: flags.remove("--environment"),
    data: flags.remove("--data").map(PathBuf::from),
    secrets: flags.remove("--secrets").map(PathBuf::from),
    report: flags.remove("--report").map(PathBuf::from),
  })
}

fn main() {
  let args: Vec<String> = std::env::args().skip(1).collect();
  if args == ["--help"] || args == ["help"] {
    println!(
      "reqeast-cli run PROJECT --workflow NAME [--environment NAME] [--data CSV|JSON] [--secrets JSON] [--report JSON]"
    );
    println!("Secrets: REQEAST_VAR_name. Exit: 0 pass, 1 test failure, 2 configuration error.");
    return;
  }
  match options(&args).and_then(|options| run::execute(&options)) {
    Ok(passed) => std::process::exit(if passed { 0 } else { 1 }),
    Err(error) => {
      eprintln!("Configuration error: {error}");
      std::process::exit(2);
    }
  }
}
