import Vapor

extension Application
{
    // convenience function for use in application context
    func github(_ endpoint: PathComponent..., type: GitHubEvent.EventType, action closure: @Sendable @escaping (Request) async -> Void)
    {
        GitHubEvent(app: self, type: type).listen(to: endpoint, action: closure)
    }
}

struct GitHubEvent
{
    let app: Application
    let type: EventType

    func listen(to endpoint: [PathComponent], action closure: @Sendable @escaping (Request) async -> Void)
    {
        let accepted = Response(status: .ok, body: .init(stringLiteral: "[mottzi] \(type.rawValue.capitalized) event request accepted."))
        let denied = Response(status: .forbidden, body: .init(stringLiteral: "[mottzi] \(type.rawValue.capitalized) event request denied."))
        
        app.post(endpoint)
        { request async -> Response in
            // validate request by verifying github signature
            let validRequest = self.validateSignature(of: request)
            
            // log initial request log based on validity
            var logger = EventLog(type: self.type, file: "deploy/github/\(type.rawValue).log")
            logger.build(request, valid: validRequest)
            logger.write()
            
            // deny request if invalid signature
            guard validRequest else { return denied }
            
            // Handle accepted request with custom action
            Task.detached { await closure(request) }
            
            // Respond immediately
            return accepted
        }
    }
    
    // verify that the request has a valid github signature
    private func validateSignature(of request: Request) -> Bool
    {
        // hard coded secret *** SECURITY RISK ***
        let secret = "4133Pratteln"
        
        // get signature
        guard let signatureHeader = request.headers.first(name: "X-Hub-Signature-256") else { return false }
        
        // ensure signature starts with "sha256="
        guard signatureHeader.hasPrefix("sha256=") else { return false }
        
        // extract signature hex string
        let signatureHex = String(signatureHeader.dropFirst("sha256=".count))
        
        // get raw request body
        guard let payload = request.body.string else { return false }
        
        // encode local secret and received payload
        guard let payloadData = payload.data(using: .utf8),
              let secretData = secret.data(using: .utf8) else { return false }
        
        // calculate expected signature
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: SymmetricKey(data: secretData))
        
        let expectedSignatureHex = signature.map { String(format: "%02x", $0) }.joined()
        
        // constant-time comparison to prevent timing attacks
        guard expectedSignatureHex.count == signatureHex.count else { return false }
        
        let valid = HMAC<SHA256>.isValidAuthenticationCode(
            signatureHex.hexadecimal ?? Data(),
            authenticating: payloadData,
            using: SymmetricKey(data: secretData)
        )
    
        return valid
    }
}
