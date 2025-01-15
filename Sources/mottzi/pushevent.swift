import Vapor

// GitHub Webhook
extension Application
{
    // listen for github push events on specified route
    func listenToPushEvents(_ route: PathComponent...)
    {
        self.post(route)
        { request async -> Response in
            // verify github signature
            guard self.validateRequest(request) else { return .denied }
            
            // react to push event
            self.handlePushEvent(request)
            
            return .success
        }
    }
    
    // verify that the request has a valid github signature
    func validateRequest(_ request: Request) -> Bool
    {
        guard request.validateSignature() else
        {
            self.log("/var/www/mottzi/pushevent.log",
            """
            === [mottzi] >>> Invalid request <<< at \(Date()) ===
                        
            ==================================================================\n\n
            """)
            
            return false
        }
        
        return true
    }
    
    func handlePushEvent(_ request: Request)
    {
        self.log("/var/www/mottzi/pushevent.log",
        """
        === [mottzi] Push event received at \(Date()) ===
        
        Request:
          Method: \(request.method.rawValue)
          URL: \(request.url.description)
        
        Headers:
        \(request.headers.map { "  \($0): \($1)" }.joined(separator: "\n"))
        
        Payload:
        \(request.body.string?.readable ?? "{}")
        
        =====================================\n\n
        """)
    }
    
    // appends content at the end of file
    func log(_ filePath: String, _ content: String)
    {
        // create log file if it does not exist
        if !FileManager.default.fileExists(atPath: filePath) {
            FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        }

        // prepare log file
        guard let file = try? FileHandle(forWritingTo: URL(fileURLWithPath: filePath)) else { return }
        guard (try? file.seekToEnd()) != nil else { return }
        guard let data = content.data(using: .utf8) else { return }
        
        // append content
        file.write(data)
        file.closeFile()
    }
}

// GitHub Webhook
extension Request
{
    // verify that the request has a valid github signature
    func validateSignature() -> Bool
    {
        // hard coded secret *** SECURITY RISK ***
        let secret = "4133Pratteln"
        
        // get signature
        guard let signatureHeader = headers.first(name: "X-Hub-Signature-256") else { return false }
        
        // ensure signature starts with "sha256="
        guard signatureHeader.hasPrefix("sha256=") else { return false }
        
        // extract signature hex string
        let signatureHex = String(signatureHeader.dropFirst("sha256=".count))
        
        // get raw request body
        guard let payload = self.body.string else { return false }
        
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

// GitHub Webhook
extension Response
{
    static let success = Response(status: .ok, body: .init(stringLiteral: "[mottzi] push-event request: valid"))
    static let denied = Response(status: .forbidden, body: .init(stringLiteral: "[mottzi] push-event request: invalid"))
}

// GitHub Webhook
extension String
{
    // tries to beautify json blobs
    var readable: String
    {
        if let jsonData = self.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
           let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let formattedString = String(data: prettyJsonData, encoding: .utf8)
        {
            return formattedString
        }
        
        return self
    }
    
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
