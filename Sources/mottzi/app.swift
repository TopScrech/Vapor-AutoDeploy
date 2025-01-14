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
        self.post("pushevent")
        { request async in
            let logFilePath = "/var/www/mottzi/pushevent.log"
            
            // Format the JSON string
            let jsonString = request.body.string ?? "{}"
            let prettyJSON: String
            do {
                if let jsonData = jsonString.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
                   let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]) {
                    prettyJSON = String(data: prettyJsonData, encoding: .utf8) ?? jsonString
                } else {
                    prettyJSON = jsonString
                }
            }
            
            // Create log entry with timestamp, headers and JSON
            var logEntry = "=== Webhook received at \(Date()) ===\n\n"
            
            // Add headers
            logEntry += "Headers:\n"
            for (name, value) in request.headers {
                logEntry += "  \(name): \(value)\n"
            }
            
            // Add formatted JSON
            logEntry += "\nPayload:\n\(prettyJSON)\n\n"
            logEntry += "=====================================\n\n"
            
            // Write to file
            if !FileManager.default.fileExists(atPath: logFilePath) {
                FileManager.default.createFile(atPath: logFilePath, contents: nil, attributes: nil)
            }
            
            do {
                let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logFilePath))
                try fileHandle.seekToEnd()
                
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                
                fileHandle.closeFile()
            } catch {
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
