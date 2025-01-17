import Vapor

struct GitHubEvent
{
    let app: Application
    let type: EventType
    
    enum EventType: String
    {
        case push
        
        func formatLog(_ request: Request) -> String?
        {
            switch self
            {
                case .push: formatPushLog(request)
            }
        }
        
        private func formatPushLog(_ request: Request) -> String?
        {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            guard let bodyString = request.body.string,
                  let jsonData = bodyString.data(using: .utf8),
                  let payload = try? decoder.decode(GitHubEvent.Payload.self, from: jsonData)
            else { return nil }
            
            let log =
            [
                "    Commit: \(payload.headCommit.id)",
                !payload.headCommit.modified.isEmpty ? "    Changed (\(payload.headCommit.modified.count)): \n        \(payload.headCommit.modified.joined(separator: ",\n        "))" : nil,
                "    Author: \(payload.headCommit.author.name)",
                "    Message: \(payload.headCommit.message)",
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
            
            return log
        }
    }
    
    func listen(to endpoint: [PathComponent], action closure: @Sendable @escaping (Request) async -> Void)
    {
        let accepted = Response(status: .ok, body: .init(stringLiteral: "[mottzi] \(type.rawValue.capitalized) event request accepted."))
        let denied = Response(status: .forbidden, body: .init(stringLiteral: "[mottzi] \(type.rawValue.capitalized) event request denied."))
        
        app.post(endpoint)
        { request async -> Response in
            // validate request by verifying github signature header
            guard self.validateRequest(request) else { return denied }
            
            // Handle accepted request with custom action
            Task.detached { await closure(request) }
            
            // Respond immediately
            return accepted
        }
    }
    
    // verify that the request has a valid github signature
    private func validateRequest(_ request: Request) -> Bool
    {
        if validateSignature(of: request)
        {
            var logContent =
            """
            =====================================================
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            Valid \(type.rawValue) event received [\(Date.now)]
            """
            
            if let commitContent = GitHubEvent.EventType.push.formatLog(request)
            {
                logContent += "\n\n\(commitContent)\n\n"
            }
            else
            {
                request.logger.error("Failed to format commit log details")
            }
            
            logContent +=
            """
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            =====================================================\n\n
            """
            
            log("deploy/github/push.log", logContent)
            return true
        }
        else
        {
            log("deploy/github/push.log",
            """
            =====================================================
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            Invalid \(type.rawValue) event received [\(Date.now)]
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            =====================================================\n\n
            """)
            
            return false
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
        
        // request.logger.info("\(valid ? "Valid" : "Invalid") webhook received: \n\nheader: \(request.headers.description)\n\n payload: \(payload)")

        return valid
    }
}

extension Application
{
    // convenience function for use in application context lol
    func github(_ endpoint: PathComponent..., type: GitHubEvent.EventType, action closure: @Sendable @escaping (Request) async -> Void)
    {
        GitHubEvent(app: self, type: type).listen(to: endpoint, action: closure)
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

extension GitHubEvent
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
            let added: [String]
            let removed: [String]
        }
        
        struct Author: Codable
        {
            let name: String
            let email: String
        }
    }
}
