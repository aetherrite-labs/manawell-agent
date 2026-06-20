//
//  BearerAuthMiddleware.swift
//  ManawellAgentCore
//

import HTTPTypes
import Hummingbird

/// Rejects any request that doesn't carry `Authorization: Bearer <secret>`. Applied to
/// the authed route group; `/v1/health` deliberately sits outside it so the phone can
/// probe reachability during pairing before it has presented credentials.
struct BearerAuthMiddleware<Context: RequestContext>: RouterMiddleware {
    let secret: String

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard let header = request.headers[.authorization],
              constantTimeEquals(header, "Bearer \(secret)")
        else {
            return Response(status: .unauthorized)
        }
        return try await next(request, context)
    }

    /// Length-independent, byte-wise comparison so token validation doesn't leak the
    /// secret through response timing.
    private func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count {
            diff |= a[i] ^ b[i]
        }
        return diff == 0
    }
}
