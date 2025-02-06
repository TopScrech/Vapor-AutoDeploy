import Vapor

extension Application
{
    // convenience function to register github webhook listener
    func push(_ endpoint: PathComponent..., action closure: @Sendable @escaping (Request) async -> ())
    {
        DeploymentWebhook(app: self).listen(to: endpoint, action: closure)
    }
}

struct DeploymentWebhook
{
    let app: Application

    // register github webhook listener
    func listen(to endpoint: [PathComponent], action closure: @Sendable @escaping (Request) async -> ())
    {
        let accepted = Response(status: .ok, body: .init(stringLiteral: "[mottzi] Push event accepted."))
        let denied = Response(status: .forbidden, body: .init(stringLiteral: "[mottzi] Push event denied."))
                
        app.post(endpoint)
        { request async -> Response in
            // validate request by verifying github signature
            let validRequest = self.validateSignature(of: request)
            
            // deny request if invalid signature
            guard validRequest else { return denied }
            
            // handle accepted request with custom action
            Task.detached { await closure(request) }
            
            // respond immediately
            return accepted
        }
    }
    
    // verify that the request has a valid github signature
    private func validateSignature(of request: Request) -> Bool
    {
        // get github secret from env file
        let secret = Environment.Variables.GITHUB_WEBHOOK_SECRET.value

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

extension DeploymentWebhook
{
    struct Payload: Codable
    {
        let headCommit: Commit
        
        struct Commit: Codable
        {
            let id: String
            let author: Author
            let message: String
            let modified: [String]
            
            struct Author: Codable
            {
                let name: String
            }
        }
    }
}

extension String
{
    // needed for signature verification
    var hexadecimal: Data?
    {
        var data = Data(capacity: count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self))
        { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        return data
    }
}
