import Vapor

extension Application
{
    // the web server will respond to the following http routes
    public func useRoutes()
    {
        // github webhook push event route
        self.github("pushevent", type: .push)
        { request async in
            // handle valid request
            await self.handlePushEvent(request)
        }
        
        self.get("admin")
        { request async throws -> View in
            let tasks = try await DeploymentTask.query(on: request.db).all()
            return try await request.view.render("deployments", ["tasks": tasks])
        }
        
        self.get("admin", "deployments")
        { request async throws -> [DeploymentTask] in
            try await DeploymentTask.query(on: request.db).all()
        }
        
        self.get("admin", "deployments", ":id")
        { request async throws -> DeploymentTask in
            guard let task = try await DeploymentTask.find(request.parameters.get("id"), on: request.db)
            else { throw Abort(.notFound) }
            
            return task
        }
        
        // mottzi.de/text
        self.get("text")
        { request in
            """
            Auto deploy: ? YAS3 ?
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
