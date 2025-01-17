import Vapor

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
            self.type.logRequest(request, valid: validRequest, type: type)
            
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

extension GitHubEvent.EventType
{
    func logRequest(_ request: Request, valid: Bool, type: Self)
    {
        var logContent = ""
        
        if valid
        {
            // valid + details
            if let details = type.detailsLogMessage(request)
            {
                logContent =
                """
                =====================================================
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                Valid \(type.rawValue) event received [\(Date.now)]
                    
                \(details)
                
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                =====================================================\n\n
                """
            }
            // valid - details
            else
            {
                logContent =
                """
                =====================================================
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                Valid \(type.rawValue) event received [\(Date.now)]
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                =====================================================\n\n
                """
            }
        }
        // invalid
        else
        {
            logContent =
            """
            =====================================================
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            Invalid \(type.rawValue) event received [\(Date.now)]
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            =====================================================\n\n
            """
        }
        
        log("deploy/github/\(type.rawValue).log", logContent)
    }
    
    func detailsLogMessage(_ request: Request) -> String?
    {
        switch self
        {
            case .push: detailsLogMessagePush(request)
            default: nil
        }
    }
    
    private func detailsLogMessagePush(_ request: Request) -> String?
    {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let bodyString = request.body.string,
              let jsonData = bodyString.data(using: .utf8),
              let payload = try? decoder.decode(GitHubEvent.Payload.self, from: jsonData)
        else { return nil }
        
        var log =
            """
                Commit: \(payload.headCommit.id)
                Author: \(payload.headCommit.author.name)
                Message: \(payload.headCommit.message)
            """
        
        guard !payload.headCommit.modified.isEmpty else { return log }
        let modified = payload.headCommit.modified.joined(separator: "")
        
        log +=
            """
            
                Changed (\(payload.headCommit.modified.count)): 
                    - \(payload.headCommit.modified.joined(separator: ",\n        - "))"
            """
        
        return log
    }
}

extension GitHubEvent
{
    enum EventType: String
    {
        case push
        case test
    }
    
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
