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
        // github webhook for push events
        self.post("pushevent")
        { request async in
            let logFile = "/var/www/mottzi/pushevent.log"
            
            var json = request.body.string ?? "{}"
            
            if let jsonData = json.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
               let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let formattedString = String(data: prettyJsonData, encoding: .utf8)
            {
                json = formattedString
            }
            
            var logEntry = "=== Webhook received at \(Date()) ===\n\n"
            
            logEntry += "Headers:\n"
            for (name, value) in request.headers
            {
                logEntry += "  \(name): \(value)\n"
            }
            
            logEntry += "\nPayload:\n\(json)\n\n"
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
                request.logger.error("Vapor: Failed to write to log file: \(error)")
                
                let response = Response(status: .internalServerError)
                response.body = .init(stringLiteral: "Internal Server Error")
                return response
            }
            
            let response = Response(status: .ok)
            response.body = .init(stringLiteral: "Vapor: Payload received and logged successfully")
            return response
        }
        
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
