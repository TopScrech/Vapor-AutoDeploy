import Vapor

extension Application
{
    func useDeployPanel()
    {
        self.webSocket("admin", "ws")
        { request, ws async in
            // on connect
            let id = UUID(
            
            // add client to internal connection list
            DeploymentPanelManager.shared.add(connection: id, socket: ws)
            
            // send welcome message to client
            if let msg = DeploymentPanalMessage(type: .message, message: "Server: Connected...").jsonString
            {
                try? await ws.send(msg)
            }
            
            // send current state to client (for reconnecting stale clients)
            if let deployments = try? await Deployment
                .query(on: request.db)
                .sort(\.$startedAt, .descending)
                .all()
                .markingStaleDeployments(),
               let state = DeploymentPanalMessage(type: .state, deployments: deployments).jsonString
            {
                try? await ws.send(state)
            }
            
            // on disconnect: remove client from internal connection list on disconnect
            ws.onClose.whenComplete()
            { _ in
                DeploymentPanelManager.shared.remove(connection: id)
            }
        }
        
        // mottzi.de/admin nn
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment
                .query(on: request.db)
                .sort(\.$startedAt, .descending)
                .all()
                .markingStaleDeployments()
            
            return try await request.view.render("deployment/panel", ["tasks": deployments])
        }
    }
}

extension Array where Element == Deployment
{
    func markingStaleDeployments() -> [Deployment]
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

