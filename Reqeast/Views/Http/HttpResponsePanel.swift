// Modified for RHEQ: visual workflows and HTTP diagnostics.
//
//  HttpResponsePanel.swift
//  Reqeast
//

import SwiftUI

struct HttpResponsePanel: View {
    var execution: HttpExecutionState
    var request: Request
    var httpData: HttpRequestData

    @State private var pulse = false
    @State private var showingDiagnostics = false

    var body: some View {
        VStack(spacing: 0) {
            if execution.response != nil || execution.error != nil {
                HStack {
                    Spacer()
                    Button("Diagnostics", systemImage: "waveform.path.ecg") { showingDiagnostics = true }
                        .buttonStyle(.glass)
                }.padding(6)
            }
            if let error = execution.workflowError {
                Label { Text(error.message).textSelection(.enabled) } icon: { Image(systemName: error.iconName) }
                    .font(.caption).foregroundStyle(.red).padding(8)
            }
            if !execution.workflowChecks.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                    ForEach(execution.workflowChecks) { check in
                        Label(check.label, systemImage: check.passed ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(check.passed ? .green : .red)
                    }
                    }
                }.font(.caption).padding(8)
            }
            if let response = execution.response {
                HttpResponseView(
                    response: response,
                    requestId: request.id,
                    requestMethod: httpData.method.rawLabel,
                    requestUrl: httpData.url,
                    requestName: request.isRenamed ? request.name : nil
                )
            } else if let error = execution.error {
                ContentUnavailableView {
                    Label(error.localizedTitle, systemImage: error.iconName)
                } description: {
                    Text(error.message)
                        .textSelection(.enabled)
                }
            } else if execution.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                        .opacity(pulse ? 0.3 : 0.8)
                        .scaleEffect(pulse ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    Text("Sending request…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { pulse = true }
                .onDisappear { pulse = false }
            } else {
                ContentUnavailableView {
                    Label("No Response", systemImage: "paperplane")
                        .foregroundStyle(.secondary)
                } description: {
                    if httpData.url.isEmpty {
                        Text("Enter a URL above to get started")
                    } else {
                        #if os(macOS)
                        Text("Press \u{2318}Return to send the request")
                        #else
                        Text("Tap Send to make the request")
                        #endif
                    }
                }
            }
        }.sheet(isPresented: $showingDiagnostics) {
            VStack {
                Form { HttpDiagnosticsView(execution: execution) }.formStyle(.grouped)
                Button("Close") { showingDiagnostics = false }.buttonStyle(.glass).padding()
            }
            #if os(macOS)
            .frame(width: 680, height: 650)
            #endif
        }
    }
}
