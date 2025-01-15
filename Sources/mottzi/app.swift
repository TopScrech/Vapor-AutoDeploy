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
        app.configureRoutes()
        
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
        self.github("pushevent")
        
        // mottzi.de/text
        self.get("text")
        { _ in
            """
            Version 2.0
            Joshi stinkt.
            """
        }

        // mottzi.de/dynamic/world
        self.get("dynamic", ":property")
        { request async in
            "Hello, \(request.parameters.get("property")!)!"
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
