import Vapor

extension Application
{
    func useDeployPanel()
    {
        self.webSocket("admin", "ws")
        { request, ws async in
            // connection is identifiable
            let id = UUID()
            
            // register client for broadcasting
            DeploymentClients.shared.add(connection: id, socket: ws)
            
            // 1. welcome message
            await DeploymentClients.Message(.message, "Server: Connected...").send(on: ws)
            
            // 2. send full state
            if let deployments = try? await Deployment.query(on: request.db).sort(\.$startedAt, .descending).all().stale()
            {
                await DeploymentClients.Message(.state, deployments).send(on: ws)
            }
            
            // remove client from broadcasting register
            ws.onClose.whenComplete() { _ in DeploymentClients.shared.remove(connection: id) }
        }
        
        // mottzi.de/admin
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment.query(on: request.db).sort(\.$startedAt, .descending).all().stale()
            
            return try await request.view.render("deployment/panel", ["tasks": deployments])
        }
    }
}

extension Array where Element == Deployment
{
    func stale() -> [Deployment]
    {
        self.map()
        {
            // Early return if not running
            guard $0.status == "running" else { return $0 }
            // Early return if no start time
            guard let startedAt = $0.startedAt else { return $0 }
            // Early return if not stale
            guard Date().timeIntervalSince(startedAt) > 1800 else { return $0 }
            
            $0.status = "stale"
            
            return $0
        }
    }
}

