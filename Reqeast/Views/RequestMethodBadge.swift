// Modified for RHEQ: small method labels without colored plates.
//
//  RequestMethodBadge.swift
//  Reqeast
//

import SwiftUI

struct RequestMethodBadge: View {
    let request: Request

    var body: some View {
        let config = badgeConfig
        Text(config.label)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(config.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

    }

    private var badgeConfig: (label: String, color: Color) {
        switch request.type {
        case .http:
            let method = request.httpData?.method ?? .get
            let color: Color = switch method {
            case .get, .put, .patch: Color("MethodBlue")
            case .post: Color("MethodAmber")
            case .delete: Color("MethodDanger")
            case .head, .options: Color("MethodMuted")
            }
            return (method.shortLabel, color)
        case .tcp:
            let useTls = request.tcpData?.useTls ?? false
            return (useTls ? "TLS" : "TCP", Color("MethodMuted"))
        case .udp:
            return ("UDP", Color("MethodMuted"))
        case .webSocket:
            return ("WS", Color("MethodMuted"))
        case .sse:
            return ("SSE", Color("MethodMuted"))
        case .grpc:
            return ("gRPC", Color("MethodMuted"))
        }
    }
}
