// Original RHEQ regression: full request duration must include delayed response body.
use std::io::{Read, Write};
use std::net::TcpListener;
use std::time::Duration;

use reqeast_core::{HttpBody, HttpMethod, HttpVersion};
use reqeast_core::{HttpClient, HttpRequestConfig};

#[test]
fn timing_includes_download_after_headers() {
  let listener = TcpListener::bind("127.0.0.1:0").unwrap();
  let address = listener.local_addr().unwrap();
  let server = std::thread::spawn(move || {
    let (mut stream, _) = listener.accept().unwrap();
    stream.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
    let mut buffer = [0_u8; 4096];
    let _ = stream.read(&mut buffer).unwrap();
    stream
      .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n")
      .unwrap();
    stream.flush().unwrap();
    std::thread::sleep(Duration::from_millis(100));
    stream.write_all(b"ok").unwrap();
  });
  let response = HttpClient::new()
    .unwrap()
    .send(HttpRequestConfig {
      url: format!("http://{address}/"),
      method: HttpMethod::Get,
      headers: vec![],
      body: HttpBody::None,
      timeout_secs: 5,
      follow_redirects: false,
      max_redirects: 0,
      ssl_verify: true,
      http_version: HttpVersion::Http1,
      encode_url: true,
      follow_original_method: false,
      follow_auth_header: false,
      remove_referer_on_redirect: false,
      cookies: vec![],
    })
    .unwrap();
  server.join().unwrap();
  let timing = response.timing.unwrap();
  assert_eq!(response.body, b"ok");
  assert!(response.elapsed_ms >= 90);
  assert!(timing.download_ms >= 90.0);
  assert!(timing.total_ms >= timing.download_ms);
  assert!((timing.dns_lookup_ms + timing.connection_ms + timing.download_ms - timing.total_ms).abs() < 1.0);
}
