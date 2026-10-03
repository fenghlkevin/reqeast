import Foundation

extension HttpService {
    func preparedAuthHeaders(url: String, method: HttpMethod, bodyContent: String,
        authType: HttpAuthType, authToken: String, authUsername: String, authPassword: String,
        authApiKeyName: String, authApiKeyValue: String, authApiKeyLocation: String,
        authData: HttpAuthData?) -> [KeyValueEntry] {
        var mergedHeaders: [KeyValueEntry] = []
        switch authType {
        case .bearer:
            if !authToken.isEmpty {
                mergedHeaders.append(KeyValueEntry(key: "Authorization", value: "Bearer \(authToken)"))
            }
        case .basic:
            if !authUsername.isEmpty {
                let credentials = "\(authUsername):\(authPassword)"
                if let data = credentials.data(using: .utf8) {
                    let encoded = data.base64EncodedString()
                    mergedHeaders.append(KeyValueEntry(key: "Authorization", value: "Basic \(encoded)"))
                }
            }
        case .apiKey:
            if !authApiKeyName.isEmpty && authApiKeyLocation == "header" {
                mergedHeaders.append(KeyValueEntry(key: authApiKeyName, value: authApiKeyValue))
            }
        case .jwtBearer:
            if let ad = authData {
                if let token = JwtAuthService.generateToken(
                    algorithm: ad.jwtAlgorithm,
                    secret: ad.jwtSecret,
                    payload: ad.jwtPayload,
                    base64Encoded: ad.jwtBase64Encoded
                ) {
                    let prefix = ad.jwtHeaderPrefix.isEmpty ? "Bearer" : ad.jwtHeaderPrefix
                    mergedHeaders.append(KeyValueEntry(key: "Authorization", value: "\(prefix) \(token)"))
                }
            }
        case .hawkAuth:
            if let ad = authData {
                if let header = HawkAuthService.generateHeader(
                    url: url,
                    method: method.rawLabel,
                    authId: ad.hawkAuthId,
                    authKey: ad.hawkAuthKey,
                    algorithm: ad.hawkAlgorithm
                ) {
                    mergedHeaders.append(KeyValueEntry(key: "Authorization", value: header))
                }
            }
        case .awsSignature:
            if let ad = authData {
                let existingHeaders = mergedHeaders.map { ($0.key, $0.value) }
                if let awsHeaders = AwsSignatureService.generateHeaders(
                    url: url,
                    method: method.rawLabel,
                    headers: existingHeaders,
                    body: bodyContent.data(using: .utf8),
                    accessKey: ad.awsAccessKey,
                    secretKey: ad.awsSecretKey,
                    region: ad.awsRegion,
                    service: ad.awsService,
                    sessionToken: ad.awsSessionToken
                ) {
                    for (key, value) in awsHeaders {
                        mergedHeaders.append(KeyValueEntry(key: key, value: value))
                    }
                }
            }
        case .akamaiEdgeGrid:
            if let ad = authData {
                if let header = AkamaiEdgeGridService.generateHeader(
                    url: url,
                    method: method.rawLabel,
                    body: bodyContent.data(using: .utf8),
                    clientToken: ad.akamaiClientToken,
                    clientSecret: ad.akamaiClientSecret,
                    accessToken: ad.akamaiAccessToken
                ) {
                    mergedHeaders.append(KeyValueEntry(key: "Authorization", value: header))
                }
            }
        case .none, .digestAuth, .oauth1, .oauth2, .ntlm:
            break
        }

        return mergedHeaders
    }
}
