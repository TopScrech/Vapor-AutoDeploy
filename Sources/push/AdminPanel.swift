import Vapor

struct AdminPanel
{
    struct DeploymentView: Encodable
    {
        let id: UUID?
        let status: String
        let startedAt: Date?
        let finishedAt: Date?
        let durationString: String?
    }
}

extension Application
{
    func useAdminPanel()
    {
        // mottzi.de/admin
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment.query(on: request.db).sort(\.$startedAt, .descending).all()
            
            let data = deployments.map()
            {
                var durationString: String? = nil
                if let finishedAt = $0.finishedAt, let startedAt = $0.startedAt {
                    let duration = finishedAt.timeIntervalSince(startedAt)
                    durationString = String(format: "%.1fs", duration)
                }
                
                return AdminPanel.DeploymentView(
                    id: $0.id,
                    status: $0.status,
                    startedAt: $0.startedAt,
                    finishedAt: $0.finishedAt,
                    durationString: durationString
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
