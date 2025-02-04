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
            await DeploymentClients.shared.add(connection: id, socket: ws)
            
            // 1. welcome message
            await DeploymentClients.Message(.message, "Server: Connected...").send(on: ws)
            
            // 2. send full state
            if let deployments = try? await Deployment.all(on: request.db)
            {
                let state = DeploymentClients.Message(.state, deployments)
                await state.send(on: ws)
            }
            
            ws.onText()
            { ws, msg async in
                guard let data = msg.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(DeploymentClients.Message.self, from: data) else { return }
                
                switch message.type
                {
                    case .deletion:
                        guard let id = message.deployment?.id else { return }
                        guard let deployment = try? await Deployment.find(id, on: request.db) else { return }
                        try? await deployment.delete(on: request.db)
                        await DeploymentClients.shared.broadcast(message)
                        
                    default: break
                }
            }
                        
            // remove client from broadcasting register
            ws.onClose.whenComplete() { _ in Task { await DeploymentClients.shared.remove(connection: id) } }
        }
        
        // mottzi.de/admin
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment.all(on: request.db)
            
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

