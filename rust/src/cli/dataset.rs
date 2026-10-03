use super::{
  Result,
  variables::{Variables, text},
};
use serde_json::Value;
use std::{collections::BTreeSet, fs, path::Path};

pub fn load(path: &Path) -> Result<Vec<Variables>> {
  if fs::metadata(path)?.len() > 1_048_576 {
    return Err("Dataset exceeds 1 MB".into());
  }
  let input = fs::read_to_string(path)?;
  let rows = if path
    .extension()
    .and_then(|v| v.to_str())
    .is_some_and(|v| v.eq_ignore_ascii_case("json"))
  {
    let value: Value = serde_json::from_str(&input)?;
    value
      .as_array()
      .ok_or("Use a JSON array")?
      .iter()
      .map(|row| {
        row
          .as_object()
          .ok_or_else(|| "Use objects for data rows".into())
          .and_then(|map| {
            map
              .iter()
              .map(|(k, v)| {
                if v.is_array() || v.is_object() || v.is_null() {
                  return Err("Data values must be scalar".into());
                }
                Ok((k.clone(), text(v)?))
              })
              .collect::<Result<Variables>>()
          })
      })
      .collect::<Result<Vec<_>>>()?
  } else {
    let records = csv(input.trim_start_matches('\u{feff}'))?;
    let header = records.first().ok_or("Missing CSV header")?;
    if header.iter().collect::<BTreeSet<_>>().len() != header.len() {
      return Err("Duplicate CSV column".into());
    }
    records
      .iter()
      .skip(1)
      .map(|row| {
        if row.len() != header.len() {
          return Err("CSV row has incorrect field count".into());
        }
        Ok(header.iter().cloned().zip(row.iter().cloned()).collect())
      })
      .collect::<Result<Vec<Variables>>>()?
  };
  let keys: BTreeSet<_> = rows.first().ok_or("Dataset has no rows")?.keys().cloned().collect();
  if rows.len() > 1000
    || keys.is_empty()
    || keys.iter().any(|k| k.is_empty() || k.contains(['{', '}']))
    || rows
      .iter()
      .any(|row| row.keys().cloned().collect::<BTreeSet<_>>() != keys)
  {
    return Err("Use matching columns and at most 1000 data rows".into());
  }
  Ok(rows)
}

fn csv(input: &str) -> Result<Vec<Vec<String>>> {
  let mut records = Vec::new();
  let mut row = Vec::new();
  let mut field = String::new();
  let mut quoted = false;
  let mut closed = false;
  let mut started = false;
  let mut chars = input.chars().peekable();
  while let Some(c) = chars.next() {
    if quoted {
      if c == '"' {
        if chars.peek() == Some(&'"') {
          chars.next();
          field.push('"');
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.push(c);
      }
    } else if c == ',' {
      row.push(std::mem::take(&mut field));
      closed = false;
      started = false;
    } else if c == '\n' || c == '\r' {
      if c == '\r' && chars.peek() == Some(&'\n') {
        chars.next();
      }
      row.push(std::mem::take(&mut field));
      records.push(std::mem::take(&mut row));
      closed = false;
      started = false;
    } else if c == '"' && !started && !closed && field.is_empty() {
      quoted = true;
      started = true;
    } else {
      if closed || c == '"' {
        return Err("Invalid CSV quoting".into());
      }
      field.push(c);
      started = true;
    }
  }
  if quoted {
    return Err("Unclosed CSV quote".into());
  }
  if started || closed || !field.is_empty() || !row.is_empty() {
    row.push(field);
    records.push(row);
  }
  Ok(records)
}

#[cfg(test)]
mod tests {
  use super::*;
  #[test]
  fn handles_quotes_and_newlines() {
    let rows = csv("a,b\r\n\"x,y\",\"one\n\"\"two\"\"\"\r\n").unwrap();
    assert_eq!(rows[1], ["x,y", "one\n\"two\""]);
    assert!(csv("\"unfinished").is_err());
  }
}
