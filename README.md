<br/>
<p align="center">
  <img src="assets/logo.png" width="200px" alt="RHEQ"></img>
</p>

# RHEQ

RHEQ is a derivative of Reqeast by Felipe Lima. It uses original RHEQ branding and a revised interface.

Native multi-protocol API client for macOS, iOS, and iPadOS. SwiftUI UI over a Rust networking core.

---

## Features

- **HTTP**: method picker, headers, body, auth, JSON tree response viewer
- **TCP/TLS**: persistent sockets with a conversation log
- **UDP**: send and receive datagrams with session management
- **WebSocket and SSE**: bidirectional streams and server-sent events
- **gRPC**: unary and streaming RPCs, server reflection, proto library
- **iCloud Sync**: projects and requests across Apple devices
- **Environments**: `{{variable}}` substitution with secret support
- **Response variables**: extract JSON fields into the selected environment for subsequent requests
- **Response comparison**: save a local JSON baseline and compare fields, with ignored paths
- **HTTP workflows**: named, saved request sequences with response checks and fixed environment selection
- **Visual workflows**: numbered request cards, variable dependencies, live step status, and response-to-header links
- **HTTP diagnostics**: send-time request capture, error guidance, DNS/download timings, redirects, certificate details, and redacted reports
- **Request inspection**: variable provenance, missing-variable checks, and a prepared request preview with masked secrets
- **Data-driven tests**: CSV/JSON rows run isolated workflows, with exportable JSON reports
- **Project files**: one JSON file per HTTP request, Git-friendly export/import, and secret references
- **Command line**: `reqeast-cli` runs exported workflows with data files, secrets, JSON reports, and CI exit codes
- **User manual**: in-app chapters with numbered instructions and real interface screenshots
- **Import**: OpenAPI, Postman, Bruno, and related collection formats (see app UI)

## Requirements

- macOS 26.0+ / iOS 26.0+ / iPadOS 26.0+
- Xcode 26.4+
- Swift 6.3+
- Rust 1.88.0+ (edition 2024)
- `just` (`brew install just`)
- `cargo-bundle-licenses` (`cargo install cargo-bundle-licenses`)

## Quick Start

```sh
just build-rust
open Reqeast.xcodeproj
```

Build and run the `Reqeast` scheme in Xcode (Mac or iOS Simulator).

## Commands

```sh
just build-rust       # Rust XCFramework + UniFFI Swift bindings
just clean-rust       # Clean Rust artifacts and ReqeastCore
just check-rust       # cargo check
just test-rust        # cargo test
just test-swift       # Swift unit tests (macOS)
just test-all         # Rust + Swift unit tests
just lint-rust        # cargo clippy -D warnings
just fmt-rust         # cargo fmt
just rebuild          # Full clean + build
```

Optional: `just test-ui`, `just test-swift-ios`, `just generate-licenses`. See `justfile` and package `AGENTS.md` files for more.

## Project structure

```
Reqeast/          # SwiftUI app (Models, Views, Services, Design, Intents)
rust/             # Networking core + UniFFI (reqwest, tonic, tokio, rustls)
ReqeastCore/      # Generated XCFramework (not committed; build with just build-rust)
ReqeastTests/     # Swift Testing unit tests
ReqeastUITests/   # XCTest UI tests
reqeast-mcp/      # Optional local MCP server for AI tools
scripts/          # i18n helpers, curlconverter bundle, screenshot tooling
```

## MCP server

The optional Node package under `reqeast-mcp/` exposes read-only session data to local AI tools. See [reqeast-mcp/README.md](reqeast-mcp/README.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

This repository is licensed under the [Apache License 2.0](LICENSE.md).

### Copyright Notice

Felipe Lima retains rights to the Reqeast name, logo, and branding assets. Those materials are not covered by the Apache License 2.0. See [LICENSE.md](LICENSE.md#copyright-notice).

### Third-party components

Third-party crates and packages keep their own licenses. See `Reqeast/Resources/licenses.json`, `Reqeast/Resources/swift-licenses.json`, and package-level license files.

---

Based on Reqeast by [Felipe Lima](https://github.com/felipefdl). Software licensed under [Apache-2.0](LICENSE.md). Reqeast logos and branding are not covered by Apache-2.0; see [Copyright Notice](LICENSE.md#copyright-notice) in LICENSE.md.

## Run HTTP workflows from the command line

Save a workflow in **HTTP Workflows → Run Requests**, then export its project from **Project Files**.

```sh
cargo build --manifest-path rust/Cargo.toml --bin reqeast-cli --release
rust/target/release/reqeast-cli run ./api-project \
  --workflow 'Order test' --environment 'Test' \
  --data cases.csv --report run-report.json
```

Set secrets with `REQEAST_VAR_name` environment variables or `--secrets secrets.json`.
Data files contain CSV headers or matching JSON object keys. Each row starts from the original environment.
Exit codes: `0` passed, `1` request/extraction/check failure, `2` configuration error.
The CLI supports none, Bearer, Basic, and API Key authentication, with text-based HTTP bodies.
Attached files and signed authentication require the app. Project export includes HTTP requests only.
Reports omit response bodies and variable values. Keep secret files out of Git and review exported data before sharing.

Open **Settings → User Manual** for 32 chapters covering quick start, everyday use, all six protocols, HTTP workflows, advanced configuration, and troubleshooting. Chapters include numbered instructions, configuration examples, and existing app screenshots where relevant.
