use super::{
  Options, Result, config, dataset, project,
  variables::{Variables, enabled, field, text},
};
use reqeast_core::HttpClient;
use serde_json::json;

pub fn execute(options: &Options) -> Result<bool> {
  let (manifest, requests) = project::load(&options.root)?;
  let workflows: Vec<_> = manifest["workflows"]
    .as_array()
    .into_iter()
    .flatten()
    .filter(|w| w["name"].as_str() == Some(&options.workflow))
    .collect();
  if workflows.len() != 1 {
    return Err("Workflow name missing or ambiguous".into());
  }
  let workflow = workflows[0];
  let ids = workflow["requestIds"].as_array().ok_or("Missing workflow requests")?;
  if ids.is_empty() {
    return Err("Workflow has no requests".into());
  }
  for id in ids {
    if !requests.contains_key(id.as_str().ok_or("Invalid workflow request")?) {
      return Err("Saved request was removed".into());
    }
  }
  let mut base = project::environment(&manifest, workflow, options.environment.as_deref())?;
  if let Some(path) = &options.secrets {
    let secret = project::read(path, 1_048_576)?;
    for (key, value) in secret.as_object().ok_or("Secrets must be a JSON object")? {
      base.insert(key.clone(), text(value)?);
    }
  }
  for (key, value) in std::env::vars().filter(|(key, _)| key.starts_with("REQEAST_VAR_")) {
    base.insert(key[12..].into(), value);
  }
  let rows = options
    .data
    .as_ref()
    .map(|path| dataset::load(path))
    .transpose()?
    .unwrap_or_else(|| vec![Variables::new()]);
  // Validate unsupported auth/body configurations before sending any request.
  for request in requests.values() {
    if ids.iter().any(|id| id == &request["id"]) {
      let data = &request["httpData"];
      if !["none", "bearer", "basic", "apiKey"].contains(&field(data, "authType").as_str())
        || field(data, "bodyType") == "binary"
        || data["bodyFormDataEntries"]
          .as_array()
          .into_iter()
          .flatten()
          .any(|v| enabled(v) && field(v, "fieldType") == "file")
      {
        return Err(
          "CLI supports none/Bearer/Basic/API Key auth and text bodies; attached files and signed auth require the app"
            .into(),
        );
      }
    }
  }
  let client = HttpClient::new()?;
  let mut report = Vec::new();
  let mut passed = true;
  'rows: for (row, values) in rows.into_iter().enumerate() {
    let mut variables = base.clone();
    variables.extend(values);
    for id in ids {
      let id = id.as_str().ok_or("Invalid request ID")?;
      let request = requests.get(id).ok_or("Missing request")?;
      let data = &request["httpData"];
      let config = config::build(data, &variables)?;
      let (ok, status, elapsed, checks, error) = match client.send(config) {
        Ok(response) => {
          let checks = super::checks::checks(data, &response, &variables)?;
          let extraction = if (200..300).contains(&response.status_code) {
            super::checks::extract(data, &response, &mut variables)
          } else {
            Ok(())
          };
          let ok = (200..300).contains(&response.status_code)
            && checks.iter().all(|c| c["passed"] == true)
            && extraction.is_ok();
          (
            ok,
            Some(response.status_code),
            Some(response.elapsed_ms),
            checks,
            extraction.err().map(|error| redact(&error.to_string(), &variables)),
          )
        }
        Err(error) => (false, None, None, vec![], Some(redact(&error.to_string(), &variables))),
      };
      println!(
        "row {} | {} | {} | HTTP {}",
        row + 1,
        if ok { "PASS" } else { "FAIL" },
        field(request, "name"),
        status.map_or("-".into(), |s| s.to_string())
      );
      report.push(json!({"requestId": id, "name": request["name"], "row": row + 1, "passed": ok, "status": status, "elapsedMs": elapsed, "checks": checks, "error": error}));
      passed &= ok;
      if !ok && workflow["stopOnFailure"].as_bool().unwrap_or(true) {
        break 'rows;
      }
    }
  }
  if let Some(path) = &options.report {
    std::fs::write(path, serde_json::to_vec_pretty(&report)?)?;
  }
  Ok(passed)
}

fn redact(message: &str, variables: &Variables) -> String {
  let mut values: Vec<_> = variables.values().filter(|value| !value.is_empty()).collect();
  values.sort_by_key(|value| std::cmp::Reverse(value.len()));
  values
    .into_iter()
    .fold(message.to_string(), |text, value| text.replace(value, "[variable]"))
}
