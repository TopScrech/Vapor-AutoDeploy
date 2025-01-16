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
        
        // Set custom log formatter for timestamp
        app.logger.logLevel = .debug
        app.logger.log(level: .debug, "Startup test message 1.")
        
        try await app.execute()
        try await app.asyncShutdown()
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
            throw Abort(.forbidden, reason: "Error: work?... ABC... HAHA")
            return """
            Version 1
            Joshi stinkt.
            """
        }

        // mottzi.de/dynamic/worldd
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
