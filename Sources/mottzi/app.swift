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
            
            // verify the signature before processing
            if let error = request.verifyGitHubSignature()
            {
                var errorLog = "=== [mottzi] Invalid request (\(error.status.code)) at \(Date()) ===\n\n"
                errorLog += "Error: \(error.body.description)\n\n"
                errorLog += "=====================================\n\n"

                if !FileManager.default.fileExists(atPath: logFile)
                {
                    FileManager.default.createFile(atPath: logFile, contents: nil, attributes: nil)
                }
                
                do
                {
                    let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logFile))
                    try fileHandle.seekToEnd()
                    
                    if let data = errorLog.data(using: .utf8)
                    {
                        fileHandle.write(data)
                    }
                    
                    fileHandle.closeFile()
                }
                catch
                {
                    request.logger.error("[mottzi] Failed to write to log file (invalid request): \(error)")
                    
                    return Response(status: .internalServerError, body: .init(stringLiteral: "[mottzi] Failed to log received but invalid push event"))
                }
                
                return error
            }
            
            var json = request.body.string ?? "{}"
            
            if let jsonData = json.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
               let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let formattedString = String(data: prettyJsonData, encoding: .utf8)
            {
                json = formattedString
            }
            
            var logEntry = "=== [mottzi] Push event received at \(Date()) ===\n\n"
            
            logEntry += "Headers:\n"
            for (name, value) in request.headers
            {
                logEntry += "  \(name): \(value)\n"
            }
            
            logEntry += "\nPayload:\n\(json)\n\n"
            
            logEntry += "Response: \("[mottzi] Push event received successfully.")\n\n"
            logEntry += "=====================================\n\n"
            
            if !FileManager.default.fileExists(atPath: logFile)
            {
                FileManager.default.createFile(atPath: logFile, contents: nil, attributes: nil)
            }
            
            do
            {
                let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logFile))
                try fileHandle.seekToEnd()
                
                if let data = logEntry.data(using: .utf8)
                {
                    fileHandle.write(data)
                }
                
                fileHandle.closeFile()
            }
            catch
            {
                request.logger.error("[mottzi] Failed to write to log file: \(error)")
                
                return Response(status: .internalServerError, body: .init(stringLiteral: "[mottzi] Failed to log received push event"))
            }
            
            return Response(status: .ok, body: .init(stringLiteral: "[mottzi] Push event received and logged successfully"))
        }
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
       
        return nil // nil means verification passed
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
