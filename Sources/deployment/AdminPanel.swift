import Vapor

extension Application
{
    func useAdminPanel()
    {
        self.webSocket("admin", "ws")
        { request, socket async in
            do
            {
                try await socket.send("Connected")
            }
            catch
            {
                
            }
            
            socket.onText { _, text in print("Received unexpected message: \(text)") }
        }
        
        // mottzi.de/admin
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment
                .query(on: request.db)
                .sort(\.$startedAt, .descending)
                .all()
            
            return try await request.view.render("deployment/panel", ["tasks": deployments])
        }

        // mottzi.de/admin/deployments
        self.get("admin", "deployments")
        { request async throws -> [Deployment] in
            try await Deployment.query(on: request.db).all()
        }

        // mottzi.de/admin/deployments/UUID....
        self.get("admin", "deployments", ":id")
        { request async throws -> Deployment in
            guard let deployment = try await Deployment.find(request.parameters.get("id"), on: request.db)
            else { throw Abort(.notFound) }
            
            return deployment
        }
    }
}
