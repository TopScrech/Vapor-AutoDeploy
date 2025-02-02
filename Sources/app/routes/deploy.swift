import Vapor

extension Application
{
    func useDeployPanel()
    {
        self.webSocket("admin", "ws")
        { req, ws async in
            let id = UUID()
            
            WebSocketManager.shared.addConnection(id: id, socket: ws)
            try? await ws.send("{ \"msg\": \"Connected...\" }")
            
            ws.onClose.whenComplete
            { _ in
                WebSocketManager.shared.removeConnection(id: id)
            }
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
    }
}
