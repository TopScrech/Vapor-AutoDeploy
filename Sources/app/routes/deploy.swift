import Vapor

extension Application
{
    func useDeployPanel()
    {
        self.webSocket("admin", "ws")
        { req, ws async in
            let id = UUID()
            
            WebSocketManager.shared.addConnection(id: id, socket: ws)
            if let msg = WebSocketMessage(type: .message, message: "Server: Connected...").jsonString
            {
                try? await ws.send(msg)
            }
            
            ws.onClose.whenComplete
            { _ in
                WebSocketManager.shared.removeConnection(id: id)
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
