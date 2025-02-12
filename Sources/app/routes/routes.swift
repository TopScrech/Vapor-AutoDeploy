import Vapor
import Leaf
import LeafKit

extension Application
{
    // the web server will respond to the following http routes
    public func useRoutes()
    {
        // mottzi.de/route
        self.get("route") { _ in "1" }
        
        // mottzi.de/template
        self.get("test")
        { request async throws in
            let comp = Mist.Component<Deployment>(name: "TestComponent", template: "TestComponent", environments: "TestEnvironment")
            
            return await comp.render(request: request) ?? "what?"
        }
        
        // mottzi.de/hello/world -> 'Hello, world!'
        self.get("hello", ":name")
        { request async in
            return "Hello, \(request.parameters.get("name")!)!"
        }
        
        // mottzi.de/error
        self.get("error")
        { request async throws in
            // manual log demo
            request.logger.error("Something bad is about to happen...")
            
            // throw error demo
            if true { throw Abort(.badRequest, reason: "Test error") }
            
            return "This will never go to client as an error will have been thrown before."
        }
        
        // mottzi.de/response
        self.get("response")
        { request async in
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
