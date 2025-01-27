import Vapor

struct AdminPanel
{
    struct DeploymentView: Encodable
    {
        let id: UUID?
        let status: String
        let startedAt: Date?
        let finishedAt: Date?
        let duration: Double?
    }
}

extension Application
{
    func useAdminPanel()
    {
        // mottzi.de/admin
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment.query(on: request.db).all()
            
            let data = deployments.map()
            {
                var duration: Double? = nil
                
                if let finishedAt = $0.finishedAt, let startedAt = $0.startedAt
                { duration = finishedAt.timeIntervalSince(startedAt) }
                
                return AdminPanel.DeploymentView(
                    id: $0.id,
                    status: $0.status,
                    startedAt: $0.startedAt,
                    finishedAt: $0.finishedAt,
                    duration: duration
                )
            }
            
            return try await request.view.render("deployments", ["tasks": data])
        }

        // mottzi.de/admin/deployments
        self.get("admin", "deployments")
        { request async throws -> [Deployment] in
            try await Deployment.query(on: request.db).all()
        }

        // mottzi.de/admin/deployments/UUID...
        self.get("admin", "deployments", ":id")
        { request async throws -> Deployment in
            guard let deployment = try await Deployment.find(request.parameters.get("id"), on: request.db)
            else { throw Abort(.notFound) }
            
            return deployment
        }
    }
}
