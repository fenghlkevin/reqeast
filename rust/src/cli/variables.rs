use super::Result;
use serde_json::Value;
use std::collections::BTreeMap;

pub type Variables = BTreeMap<String, String>;

pub fn substitute(input: &str, variables: &Variables) -> Result<String> {
  let mut output = String::new();
  let mut rest = input;
  while let Some(start) = rest.find("{{") {
    output.push_str(&rest[..start]);
    let suffix = &rest[start + 2..];
    let end = suffix.find("}}").ok_or("Unclosed variable reference")?;
    let key = &suffix[..end];
    output.push_str(variables.get(key).ok_or_else(|| format!("Missing variable: {key}"))?);
    rest = &suffix[end + 2..];
  }
  output.push_str(rest);
  Ok(output)
}

pub fn text(value: &Value) -> Result<String> {
  match value {
    Value::String(text) => Ok(text.clone()),
    Value::Null => Err("Null fields cannot be used as variables".into()),
    other => Ok(serde_json::to_string(other)?),
  }
}

pub fn field(object: &Value, key: &str) -> String {
  object[key].as_str().unwrap_or("").to_string()
}
pub fn enabled(value: &Value) -> bool {
  value["enabled"].as_bool().unwrap_or(true)
}

#[cfg(test)]
mod tests {
  use super::*;
  #[test]
  fn substitution_is_single_pass_and_reports_missing() {
    let values = Variables::from([("a".into(), "{{b}}".into())]);
    assert_eq!(substitute("x{{a}}", &values).unwrap(), "x{{b}}");
    assert!(substitute("{{missing}}", &values).is_err());
  }
}
