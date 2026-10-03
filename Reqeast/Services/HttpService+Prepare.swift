import Foundation

extension HttpService {
    func prepare(
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
    ) -> HttpRequestConfig {
        var mergedHeaders = headers.filter { $0.enabled && !$0.key.isEmpty }

        mergedHeaders += preparedAuthHeaders(url: url, method: method, bodyContent: bodyContent,
            authType: authType, authToken: authToken, authUsername: authUsername, authPassword: authPassword,
            authApiKeyName: authApiKeyName, authApiKeyValue: authApiKeyValue, authApiKeyLocation: authApiKeyLocation,
            authData: authData)

        var finalUrl = url

        let enabledParams = params.filter { $0.enabled && !$0.key.isEmpty }
        if !enabledParams.isEmpty {
            let queryString = enabledParams.map { entry in
                let key = entry.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entry.key
                let value = entry.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entry.value
                return "\(key)=\(value)"
            }.joined(separator: "&")
            let separator = finalUrl.contains("?") ? "&" : "?"
            finalUrl += "\(separator)\(queryString)"
        }

        if authType == .apiKey && authApiKeyLocation == "query" && !authApiKeyName.isEmpty {
            let separator = finalUrl.contains("?") ? "&" : "?"
            finalUrl += "\(separator)\(authApiKeyName)=\(authApiKeyValue)"
        }

        let rustHeaders = mergedHeaders.map {
            KeyValuePair(key: $0.key, value: $0.value, enabled: true)
        }

        let rustBody: HttpBody
        switch bodyType {
        case .json:
            rustBody = .json(content: bodyContent)
        case .urlencoded:
            let fields = bodyFormData
                .filter { $0.enabled && !$0.key.isEmpty }
                .map { KeyValuePair(key: $0.key, value: $0.value, enabled: true) }
            rustBody = .formUrlencoded(fields: fields)
        case .raw:
            rustBody = .raw(content: bodyContent, contentType: rawContentType)
        case .binary:
            rustBody = .binary(data: binaryData ?? Data(), contentType: "application/octet-stream")
        case .formData:
            let fields = bodyFormDataEntries
                .filter { $0.enabled && !$0.key.isEmpty }
                .map { entry -> MultipartField in
                    if entry.fieldType == .file {
                        let fileData = formDataFiles[entry.id] ?? Data()
                        return MultipartField(
                            name: entry.key,
                            value: fileData,
                            fileName: entry.fileName.isEmpty ? nil : entry.fileName,
                            contentType: entry.mimeType.isEmpty ? nil : entry.mimeType,
                            isFile: true
                        )
                    } else {
                        return MultipartField(
                            name: entry.key,
                            value: Data(entry.value.utf8),
                            fileName: nil,
                            contentType: nil,
                            isFile: false
                        )
                    }
                }
            rustBody = .multipart(fields: fields)
        case .none:
            rustBody = .none
        }

        let rustHttpVersion: HttpVersion = switch httpVersion {
        case "http1": .http1
        case "http2": .http2
        default: .auto
        }

        let config = HttpRequestConfig(
            url: finalUrl,
            method: method,
            headers: rustHeaders,
            body: rustBody,
            timeoutSecs: UInt32(clamping: timeoutSeconds),
            followRedirects: followRedirects,
            maxRedirects: UInt32(clamping: maxRedirects),
            sslVerify: sslVerify,
            httpVersion: rustHttpVersion,
            encodeUrl: encodeUrl,
            followOriginalMethod: followOriginalMethod,
            followAuthHeader: followAuthHeader,
            removeRefererOnRedirect: removeRefererOnRedirect,
            cookies: CookieStore.shared.cookiesForUrl(finalUrl)
        )

        return config
    }

}
