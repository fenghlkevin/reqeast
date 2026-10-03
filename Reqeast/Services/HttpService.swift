//
//  HttpService.swift
//  Reqeast
//

import Foundation
import os

private let logger = Logger(subsystem: "app.reqeast", category: "HttpService")

final class HttpService: Sendable {
    static let shared = HttpService()

    private let client: HttpClient?

    private init() {
        do {
            self.client = try HttpClient()
        } catch {
            logger.error("Failed to initialize HttpClient: \(error)")
            self.client = nil
        }
        initLogging()
    }

    static func warmUp() {
        _ = shared
    }

    func send(
        url: String,
        method: HttpMethod,
        headers: [KeyValueEntry],
        params: [KeyValueEntry],
        bodyType: HttpBodyType,
        bodyContent: String,
        bodyFormData: [KeyValueEntry],
        bodyFormDataEntries: [FormDataEntry] = [],
        formDataFiles: [UUID: Data] = [:],
        binaryData: Data?,
        authType: HttpAuthType,
        authToken: String,
        authUsername: String,
        authPassword: String,
        authApiKeyName: String,
        authApiKeyValue: String,
        authApiKeyLocation: String,
        authData: HttpAuthData? = nil,
        followRedirects: Bool,
        timeoutSeconds: Int,
        sslVerify: Bool = true,
        httpVersion: String = "auto",
        maxRedirects: Int = 10,
        encodeUrl: Bool = true,
        followOriginalMethod: Bool = false,
        followAuthHeader: Bool = false,
        removeRefererOnRedirect: Bool = false,
        rawContentType: String = "text/plain"
    ) async -> Result<HttpResponseData, Error> {
        let config = prepare(
            url: url,
            method: method,
            headers: headers,
            params: params,
            bodyType: bodyType,
            bodyContent: bodyContent,
            bodyFormData: bodyFormData,
            bodyFormDataEntries: bodyFormDataEntries,
            formDataFiles: formDataFiles,
            binaryData: binaryData,
            authType: authType,
            authToken: authToken,
            authUsername: authUsername,
            authPassword: authPassword,
            authApiKeyName: authApiKeyName,
            authApiKeyValue: authApiKeyValue,
            authApiKeyLocation: authApiKeyLocation,
            authData: authData,
            followRedirects: followRedirects,
            timeoutSeconds: timeoutSeconds,
            sslVerify: sslVerify,
            httpVersion: httpVersion,
            maxRedirects: maxRedirects,
            encodeUrl: encodeUrl,
            followOriginalMethod: followOriginalMethod,
            followAuthHeader: followAuthHeader,
            removeRefererOnRedirect: removeRefererOnRedirect,
            rawContentType: rawContentType
        )
        return await sendPrepared(config)
    }

    func sendPrepared(_ config: HttpRequestConfig) async -> Result<HttpResponseData, Error> {
        guard let client else {
            return .failure(NSError(domain: "app.reqeast", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "HTTP client failed to initialize"
            ]))
        }

        do {
            // Background the synchronous UniFFI call so the caller's actor isn't blocked.
            let rustResponse = try await sendOnBackground(client: client, config: config)

            let responseHeaders = rustResponse.headers.map {
                KeyValueEntry(key: $0.key, value: $0.value)
            }

            let responseCookies = rustResponse.cookies.map { rc in
                StoredCookie(
                    name: rc.name,
                    value: rc.value,
                    domain: rc.domain,
                    path: rc.path,
                    expires: rc.expires,
                    httpOnly: rc.httpOnly,
                    secure: rc.secure,
                    sameSite: rc.sameSite
                )
            }

            let timing = rustResponse.timing.map { StoredTimingBreakdown(from: $0) }
            let certificate = rustResponse.certificate.map { StoredCertificateInfo(from: $0) }
            let sizeInfo = rustResponse.sizeInfo.map { StoredSizeInfo(from: $0) }
            let redirectChain = rustResponse.redirectChain.map { StoredRedirectEntry(from: $0) }

            let response = HttpResponseData(
                statusCode: Int(rustResponse.statusCode),
                statusText: rustResponse.statusText,
                headers: responseHeaders,
                body: Data(rustResponse.body),
                elapsedMs: Double(rustResponse.elapsedMs),
                bodySize: Int64(rustResponse.bodySize),
                finalUrl: rustResponse.finalUrl,
                timestamp: Date(),
                cookies: responseCookies,
                httpVersion: rustResponse.httpVersion,
                remoteAddr: rustResponse.remoteAddr,
                timing: timing,
                certificate: certificate,
                sizeInfo: sizeInfo,
                redirectChain: redirectChain
            )

            return .success(response)
        } catch {
            return .failure(error)
        }
    }

}


extension HttpService {
    @concurrent
    private func sendOnBackground(client: HttpClient, config: HttpRequestConfig) async throws -> HttpResponse {
        try client.send(config: config)
    }
}
