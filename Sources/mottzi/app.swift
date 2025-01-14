import Vapor
import Leaf

@main
struct mottzi
{
    static func main() async throws
    {
        let env = try Environment.detect()
        let app = try await Application.make(env)

        app.views.use(.leaf)
        app.setupRoutes()
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}

extension Application
{
    func setupRoutes()
    {
        self.listenToPushEvents("pushevent")
        
        self.get("text")
        { _ in
            """
            Version 2.0
            Joshi stinkt.
            """
        }

        self.get("dynamic", ":property")
        { request async in
            "Hello, \(request.parameters.get("property")!)!"
        }
        
        self.get("infile")
        { request async throws in
            try await request.view.render("htmlFile")
        }
        
        self.get("inline")
        { _ in
            let response = Response(status: .ok)
            response.headers.contentType = .html
            response.body = .init(stringLiteral:
            """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <title>Index Page</title>
            </head>
            <body>
                <h1>inline</h1>
                <p>This html page is defined in the route definition.</p>
            </body>
            </html>
            """)
            
            return response
        }
    }
}

extension Application
{
    // verify request comes from github
    // log request headers, body (payload) and success text
    // return a response.
    func listenToPushEvents(_ route: PathComponent...)
    {
        self.post(route)
        { request async in
            let logFile = "/var/www/mottzi/pushevent.log"
            
            // verify the github signature, log verification error, abort
            if let verificationError = request.verifyGitHubSignature()
            {
                let errorLog =
                """
                === [mottzi] Invalid request (\(verificationError.status.code)) at \(Date()) ===
                
                Error: \(verificationError.body.description)
                
                =====================================\n\n
                """
                
                if self.logPushEvent(errorLog) == false
                {
                    return Response(status: .internalServerError, body: .init(stringLiteral: "[mottzi] Failed to log invalid push-event request"))
                }
        
                return verificationError
            }
            
            var json = request.body.string ?? "{}"
            
            if let jsonData = json.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
               let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let formattedString = String(data: prettyJsonData, encoding: .utf8)
            {
                json = formattedString
            }
            
            let requestLog =
            """
            === [mottzi] Push event received at \(Date()) ===

            Request:
              Method: \(request.method.rawValue)
              URL: \(request.url.description)

            Headers:
            \(request.headers.map { "  \($0): \($1)" }.joined(separator: "\n"))

            Payload:
            \(json)

            =====================================\n\n
            """
            
            if self.logPushEvent(requestLog) == false
            {
                return Response(status: .internalServerError, body: .init(stringLiteral: "[mottzi] Failed to log valid push-event request"))
            }
            
            return Response(status: .ok, body: .init(stringLiteral: "[mottzi] Logged valid push-event request"))
        }
    }
    
    func logPushEvent(_ content: String) -> Bool
    {
        let path = "/var/www/mottzi/pushevent.log"
        
        if !FileManager.default.fileExists(atPath: path)
        {
            FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        }
        
        let file: FileHandle
        
        do
        {
            file = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            try file.seekToEnd()
        }
        catch
        {
            return false
        }
        
        if let data = content.data(using: .utf8)
        {
            file.write(data)
        }
        
        file.closeFile()
        
        return true
    }
}

extension Request
{
    // this will verify that the request actually came from github
    func verifyGitHubSignature() -> Response?
    {
        // hard coded secret *** SECURITY RISK ***
        let secret = "4133Pratteln"
        
        // get signature
        guard let signatureHeader = headers.first(name: "X-Hub-Signature-256") else
        {
            return Response(status: .forbidden, body: .init(string: "Missing X-Hub-Signature-256 header"))
        }
        
        // ensure signature starts with "sha256="
        guard signatureHeader.hasPrefix("sha256=") else
        {
            return Response(status: .forbidden, body: .init(string: "Invalid signature format"))
        }
        
        // extract signature hex string
        let signatureHex = String(signatureHeader.dropFirst("sha256=".count))
        
        // get raw request body
        guard let payload = self.body.string else
        {
            return Response(status: .badRequest, body: .init(string: "Missing request body"))
        }
        
        // encode local secret and received payload
        guard let secretData = secret.data(using: .utf8),
              let payloadData = payload.data(using: .utf8) else
        {
            return Response(status: .internalServerError, body: .init(string: "Encoding error"))
        }
        
        // calculate expected signature
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: SymmetricKey(data: secretData))
        
        let expectedSignatureHex = signature.map { String(format: "%02x", $0) }.joined()
        
        // constant-time comparison to prevent timing attacks
        guard expectedSignatureHex.count == signatureHex.count else
        {
            return Response(status: .forbidden, body: .init(string: "Invalid signature length"))
        }
        
        let valid = HMAC<SHA256>.isValidAuthenticationCode(
            signatureHex.hexadecimal ?? Data(),
            authenticating: payloadData,
            using: SymmetricKey(data: secretData)
        )
        
        if !valid
        {
            return Response(status: .forbidden, body: .init(string: "Invalid signature"))
        }
       
        return nil // nil means verification passed...
    }
}

extension String
{
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
