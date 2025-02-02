import Vapor

extension Application
{
    func useDeployPanel()
    {
        self.webSocket("admin", "ws")
        { request, ws async in
            // on connect
            let id = UUID()
            
            // add client to internal connection list
            DeploymentPanelManager.shared.add(connection: id, socket: ws)
            
            // send welcome message to client
            if let msg = DeploymentPanalMessage(type: .message, message: "Server: Connected...").jsonString
            {
                try? await ws.send(msg)
            }
            
            // send current state to client
            if let deployments = try? await Deployment
                .query(on: request.db)
                .sort(\.$startedAt, .descending)
                .all(),
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
            
            return try await request.view.render("deployment/panel", ["tasks": deployments])
        }
    }
}
