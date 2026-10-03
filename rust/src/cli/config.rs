use super::{
  Result,
  variables::{Variables, enabled, field, substitute},
};
use base64::{Engine, engine::general_purpose::STANDARD};
use reqeast_core::{HttpBody, HttpMethod, HttpRequestConfig, HttpVersion, KeyValuePair, MultipartField};
use serde_json::Value;

pub fn build(data: &Value, vars: &Variables) -> Result<HttpRequestConfig> {
  let sub = |key| substitute(&field(data, key), vars);
  let method = match field(data, "method").as_str() {
    "GET" => HttpMethod::Get,
    "POST" => HttpMethod::Post,
    "PUT" => HttpMethod::Put,
    "PATCH" => HttpMethod::Patch,
    "DELETE" => HttpMethod::Delete,
    "HEAD" => HttpMethod::Head,
    "OPTIONS" => HttpMethod::Options,
    _ => return Err("Unsupported HTTP method".into()),
  };
  let mut url = reqwest::Url::parse(&sub("url")?).map_err(|_| "Invalid request URL")?;
  let mut headers = pairs(&data["headers"], vars)?;
  for param in pairs(&data["params"], vars)? {
    url.query_pairs_mut().append_pair(&param.key, &param.value);
  }
  match field(data, "authType").as_str() {
    "none" | "" => {}
    "bearer" => headers.push(pair("Authorization".into(), format!("Bearer {}", sub("authToken")?))),
    "basic" => headers.push(pair(
      "Authorization".into(),
      format!(
        "Basic {}",
        STANDARD.encode(format!("{}:{}", sub("authUsername")?, sub("authPassword")?))
      ),
    )),
    "apiKey" => {
      if field(data, "authApiKeyLocation") == "query" {
        url
          .query_pairs_mut()
          .append_pair(&sub("authApiKeyName")?, &sub("authApiKeyValue")?);
      } else {
        headers.push(pair(sub("authApiKeyName")?, sub("authApiKeyValue")?));
      }
    }
    _ => {
      return Err(
        "CLI supports none, Bearer, Basic and API Key authentication; use a generated token for other schemes".into(),
      );
    }
  }
  let body = if matches!(method, HttpMethod::Get | HttpMethod::Head | HttpMethod::Options) {
    HttpBody::None
  } else {
    match field(data, "bodyType").as_str() {
      "none" | "" => HttpBody::None,
      "json" => HttpBody::Json {
        content: sub("bodyContent")?,
      },
      "raw" => HttpBody::Raw {
        content: sub("bodyContent")?,
        content_type: match field(data, "rawContentType").as_str() {
          "json" => "application/json",
          "xml" => "application/xml",
          "html" => "text/html",
          "javascript" => "application/javascript",
          _ => "text/plain",
        }
        .into(),
      },
      "urlencoded" => HttpBody::FormUrlencoded {
        fields: pairs(&data["bodyFormData"], vars)?,
      },
      "formData" => {
        let mut fields = Vec::new();
        for item in data["bodyFormDataEntries"]
          .as_array()
          .into_iter()
          .flatten()
          .filter(|v| enabled(v) && !field(v, "key").is_empty())
        {
          if field(item, "fieldType") == "file" {
            return Err("CLI does not export attached files".into());
          }
          fields.push(MultipartField {
            name: substitute(&field(item, "key"), vars)?,
            value: substitute(&field(item, "value"), vars)?.into_bytes(),
            file_name: None,
            content_type: None,
            is_file: false,
          });
        }
        HttpBody::Multipart { fields }
      }
      _ => return Err("Unsupported CLI body type or missing attachment".into()),
    }
  };
  let timeout = data["timeoutSeconds"].as_u64().unwrap_or(30);
  let redirects = data["maxRedirects"].as_u64().unwrap_or(10);
  if timeout == 0 || timeout > 3600 || redirects > 100 {
    return Err("Invalid timeout or redirect limit".into());
  }
  Ok(HttpRequestConfig {
    url: url.to_string(),
    method,
    headers,
    body,
    timeout_secs: timeout as u32,
    follow_redirects: data["followRedirects"].as_bool().unwrap_or(true),
    max_redirects: redirects as u32,
    ssl_verify: data["sslVerify"].as_bool().unwrap_or(true),
    http_version: match field(data, "httpVersion").as_str() {
      "http1" => HttpVersion::Http1,
      "http2" => HttpVersion::Http2,
      _ => HttpVersion::Auto,
    },
    encode_url: data["encodeUrl"].as_bool().unwrap_or(true),
    follow_original_method: data["followOriginalMethod"].as_bool().unwrap_or(false),
    follow_auth_header: data["followAuthHeader"].as_bool().unwrap_or(false),
    remove_referer_on_redirect: data["removeRefererOnRedirect"].as_bool().unwrap_or(false),
    cookies: vec![],
  })
}

fn pair(key: String, value: String) -> KeyValuePair {
  KeyValuePair {
    key,
    value,
    enabled: true,
  }
}
fn pairs(value: &Value, vars: &Variables) -> Result<Vec<KeyValuePair>> {
  value
    .as_array()
    .into_iter()
    .flatten()
    .filter(|v| enabled(v) && !field(v, "key").is_empty())
    .map(|v| {
      Ok(pair(
        substitute(&field(v, "key"), vars)?,
        substitute(&field(v, "value"), vars)?,
      ))
    })
    .collect()
}
