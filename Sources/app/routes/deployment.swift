import Vapor

extension Application
{
    func useDeployPanel()
    {
        self.webSocket("admin", "ws")
        { request, ws async in
            // make client connection identifiable
            let id = UUID()
            // register client for broadcasting
            await DeploymentClients.shared.add(connection: id, socket: ws)
            // server welcome message to client
            await Deployment.Message.message("Client connected to Server").send(on: ws)
            // send full server state to client (try db fetch)
            if let deployments = try? await Deployment.all(on: request.db)
            { await Deployment.Message.state(deployments).send(on: ws) }
            // Handle incoming messages
            ws.onText() { ws, text async in await WebSocket.handleDeploymentMessage(ws, text, request) }
            // remove client from broadcasting register
            ws.onClose.whenComplete() { _ in Task { await DeploymentClients.shared.remove(connection: id) } }
        }
        
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment.all(on: request.db)
            
            return try await request.view.render("deployment/panel", ["tasks": deployments])
        }
    }
}

extension WebSocket
{
    // handles incoming deployment messages from client
    static func handleDeploymentMessage(_ ws: WebSocket, _ text: String, _ request: Request) async
    {
        // decode client message
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Deployment.Message.self, from: data)
        else { return }
        
        switch message
        {
            // handle client deletion request
            case .delete(let id): do
            {
                // remove datbase entry
                guard let deployment = try? await Deployment.find(id, on: request.db) else { return }
                guard (try? await deployment.delete(on: request.db)) != nil else { return }
                
                // echo back the same message
                try? await ws.send(text)
            }
                
            default: return
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

