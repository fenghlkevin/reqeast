import Foundation

@MainActor
enum HttpSendPreparation {
    static func config(data: HttpRequestData, environment: ApiEnvironment?, sessionStore: HttpSessionStore) -> HttpRequestConfig {
        let strictMode = UserDefaults.standard.object(forKey: "strictHttpMode") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "strictHttpMode")
        let stripBody = strictMode && !data.method.conventionallyHasBody

        let sub = { (input: String) -> String in
            EnvironmentVariableService.substitute(input, environment: environment)
        }

        return HttpService.shared.prepare(
            url: UrlNormalizer.normalize(sub(data.url)),
            method: data.method,
            headers: data.headers.map {
                KeyValueEntry(id: $0.id, key: sub($0.key), value: sub($0.value), enabled: $0.enabled)
            },
            params: data.params.map {
                KeyValueEntry(id: $0.id, key: sub($0.key), value: sub($0.value), enabled: $0.enabled)
            },
            bodyType: stripBody ? .none : data.bodyType,
            bodyContent: sub(data.bodyContent),
            bodyFormData: data.bodyFormData.map {
                KeyValueEntry(id: $0.id, key: sub($0.key), value: sub($0.value), enabled: $0.enabled)
            },
            bodyFormDataEntries: data.bodyFormDataEntries.map {
                var entry = $0
                entry.key = sub(entry.key)
                if entry.fieldType == .text { entry.value = sub(entry.value) }
                return entry
            },
            formDataFiles: sessionStore.formDataFiles,
            binaryData: sessionStore.binaryBodyData,
            authType: data.authType,
            authToken: sub(data.authToken),
            authUsername: sub(data.authUsername),
            authPassword: sub(data.authPassword),
            authApiKeyName: sub(data.authApiKeyName),
            authApiKeyValue: sub(data.authApiKeyValue),
            authApiKeyLocation: data.authApiKeyLocation,
            authData: RequestVariableService.resolveAuth(data.authData, environment: environment),
            followRedirects: data.followRedirects,
            timeoutSeconds: data.timeoutSeconds,
            sslVerify: data.sslVerify,
            httpVersion: data.httpVersion,
            maxRedirects: data.maxRedirects,
            encodeUrl: data.encodeUrl,
            followOriginalMethod: data.followOriginalMethod,
            followAuthHeader: data.followAuthHeader,
            removeRefererOnRedirect: data.removeRefererOnRedirect,
            rawContentType: data.rawContentType?.mimeType ?? "text/plain"
        )

    }
}
