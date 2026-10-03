use super::{
  Result,
  variables::{Variables, enabled, field, substitute, text},
};
use reqeast_core::HttpResponse;
use serde_json::{Value, json};

fn document(response: &HttpResponse) -> Result<Value> {
  if response.body.len() > 1_048_576 {
    return Err("JSON response exceeds 1 MB".into());
  }
  Ok(serde_json::from_slice(&response.body)?)
}
pub fn extract(data: &Value, response: &HttpResponse, variables: &mut Variables) -> Result<()> {
  let rules: Vec<_> = data["workflow"]["extractions"]
    .as_array()
    .into_iter()
    .flatten()
    .filter(|v| enabled(v))
    .collect();
  if rules.is_empty() {
    return Ok(());
  }
  let doc = document(response)?;
  let mut staged = Variables::new();
  for rule in rules {
    let key = field(rule, "variable").trim().to_string();
    if key.is_empty() || key.contains(['{', '}']) || staged.contains_key(&key) {
      return Err("Invalid extraction variable".into());
    }
    staged.insert(
      key,
      text(doc.pointer(&field(rule, "pointer")).ok_or("Missing response field")?)?,
    );
  }
  variables.extend(staged);
  Ok(())
}
pub fn checks(data: &Value, response: &HttpResponse, variables: &Variables) -> Result<Vec<Value>> {
  data["workflow"]["assertions"]
    .as_array()
    .into_iter()
    .flatten()
    .filter(|v| enabled(v))
    .map(|rule| {
      let expected = substitute(&field(rule, "expected"), variables)?;
      let passed = match field(rule, "kind").as_str() {
        "status" => expected.parse::<u16>().ok() == Some(response.status_code),
        "elapsed" => expected
          .parse::<f64>()
          .is_ok_and(|v| v > 0.0 && (response.elapsed_ms as f64) < v),
        "jsonValue" => document(response)
          .ok()
          .and_then(|doc| doc.pointer(&field(rule, "pointer")).and_then(|v| text(v).ok()))
          .is_some_and(|v| v == expected),
        _ => false,
      };
      Ok(json!({"kind": rule["kind"], "passed": passed}))
    })
    .collect()
}
