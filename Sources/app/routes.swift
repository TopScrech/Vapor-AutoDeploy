import Vapor

extension Application
{
    // auto deploy setup and control panel
    func usePushEvents()
    {
        // github webhook push event route
        self.pushed("pushevent")
        { request async in
            // handle valid request
            await self.handlePushEvent(request)
        }
    }

    // the web server will respond to the following http routes
    public func useRoutes()
    {
        // mottzi.de/text
        self.get("text")
        { request in
            """
            Auto Deploy: please
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
