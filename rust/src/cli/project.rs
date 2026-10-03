use super::{
  Result,
  variables::{Variables, enabled, field},
};
use serde_json::Value;
use std::{collections::BTreeMap, fs, path::Path};

pub fn read(path: &Path, max_bytes: u64) -> Result<Value> {
  let metadata = fs::symlink_metadata(path)?;
  if metadata.file_type().is_symlink() || !metadata.is_file() || metadata.len() > max_bytes {
    return Err("Invalid or oversized project file".into());
  }
  Ok(serde_json::from_slice(&fs::read(path)?)?)
}

pub fn load(root: &Path) -> Result<(Value, BTreeMap<String, Value>)> {
  if fs::symlink_metadata(root.join("requests"))?.file_type().is_symlink() {
    return Err("Request directory cannot be a symlink".into());
  }
  let manifest = read(&root.join("reqeast.json"), 20 * 1_048_576)?;
  if manifest["format"].as_u64() != Some(1) {
    return Err("Unsupported project format".into());
  }
  let ids = manifest["requestIds"].as_array().ok_or("Missing request list")?;
  if ids.len() > 10_000 {
    return Err("Too many requests".into());
  }
  let mut requests = BTreeMap::new();
  let mut total = fs::metadata(root.join("reqeast.json"))?.len();
  for value in ids {
    let id = value.as_str().ok_or("Invalid request identifier")?;
    if id.len() != 36 || !id.chars().all(|c| c.is_ascii_hexdigit() || c == '-') {
      return Err("Invalid request identifier".into());
    }
    let path = root.join("requests").join(format!("{id}.json"));
    total += fs::symlink_metadata(&path)?.len();
    if total > 20 * 1_048_576 {
      return Err("Project exceeds 20 MB".into());
    }
    let request = read(&path, 20 * 1_048_576)?;
    if request["id"].as_str() != Some(id) || requests.insert(id.to_string(), request).is_some() {
      return Err("Mismatched or duplicate request identifier".into());
    }
  }
  Ok((manifest, requests))
}

pub fn environment(manifest: &Value, workflow: &Value, name: Option<&str>) -> Result<Variables> {
  let environments = manifest["environments"].as_array().cloned().unwrap_or_default();
  let environment = if let Some(name) = name {
    let matches: Vec<_> = environments
      .iter()
      .filter(|e| e["name"].as_str() == Some(name))
      .collect();
    if matches.len() != 1 {
      return Err("Environment name missing or ambiguous".into());
    }
    matches.first().copied()
  } else if let Some(id) = workflow["environmentId"].as_str() {
    Some(
      environments
        .iter()
        .find(|e| e["id"].as_str() == Some(id))
        .ok_or("Saved environment was removed")?,
    )
  } else {
    environments.first()
  };
  Ok(
    environment
      .into_iter()
      .flat_map(|e| e["variables"].as_array().into_iter().flatten())
      .filter(|v| enabled(v) && !(v["isSecret"].as_bool() == Some(true) && field(v, "value").is_empty()))
      .map(|v| (field(v, "key"), field(v, "value")))
      .collect(),
  )
}
