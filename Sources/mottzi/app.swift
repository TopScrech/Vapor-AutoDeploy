import Vapor
import Leaf

@main
struct mottzi
{
    static func main() async throws
    {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)
        app.views.use(.leaf)
        app.configureRoutes()
        
        app.logger = Logger(label: "com.example.timestampedLogger") { label in
            return StreamLogHandler.standardOutput(label: label)
        }
        
        // Set custom log formatter for timestamp
        app.logger.logLevel = .debug
        
        // Log a "Startup test message" with timestamp
        app.logger.logWithTimestamp(level: .debug, message: "Startup test message 9")
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}

extension Logger {
    // Custom log format including timestamp
    func logWithTimestamp(level: Logger.Level, message: String) {
        let timestamp = DateFormatter.timestampFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level)] \(message)"
        self.log(level: level, "\(logMessage)")
    }
}

extension DateFormatter {
    // Formatter for the timestamp (you can customize the format here)
    static var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }
}

// Routes
extension Application
{
    // the web server will respond to these following http requests
    func configureRoutes()
    {
        // this will notify app off github push events
        self.github("pushevent")
        
        // mottzi.de/text
        self.get("text")
        { req throws in
            throw Abort(.forbidden, reason: "Error: 3.0... ABC... HAHA")
            return """
            Version 1
            Joshi stinkt.
            """
        }

        // mottzi.de/dynamic/world
        self.get("dynamic", ":property")
        { request async in
            request.logger.error("TestError here")
            return "Hello, \(request.parameters.get("property")!)!"
        }
        
        // mottzi.de/infile
        self.get("infile")
        { request async throws in
            try await request.view.render("htmlFile")
        }
        
        // mottzi.de/inline
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
