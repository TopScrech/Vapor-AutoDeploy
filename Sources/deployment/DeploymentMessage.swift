import Vapor

extension Deployment
{
    // server-client message protocol
    enum Message: Codable
    {
        case create(deployment: Deployment)
        case update(deployment: Deployment)
        case delete(id: UUID)
        case state(deployments: [Deployment])
        case message(message: String)
    }
}

// send message
extension Deployment.Message
{
    // sends deployment message using a websocket
    func send(on ws: WebSocket) async
    {
        if let jsonString { try? await ws.send(jsonString) }
    }
    
    // convert enum case with its associated values to json
    var jsonString: String?
    {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        
        return jsonString
    }
}

// message factories for convenience
extension Deployment.Message
{
    static func create(_ deployment: Deployment) -> Self { Self.create(deployment: deployment) }
    static func update(_ deployment: Deployment) -> Self { Self.update(deployment: deployment) }
    static func delete(_ id: UUID) -> Self { Self.delete(id: id) }
    static func state(_ deployments: [Deployment]) -> Self { Self.state(deployments: deployments) }
    static func message(_ message: String) -> Self { Self.message(message: message) }
}

extension WebSocket
{
    // handles incoming deletion messages from clients
    static func handleDeploymentMessage(_ ws: WebSocket, _ text: String, _ request: Request) async
    {
        // abort if client json couldnt be decoded to a deployment message
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(Deployment.Message.self, from: data)
        else { return }
        
        // abort if server received anything but delete message
        guard case .delete(let id) = message else { return }
        
        // abort if there is no datbase entry with received id
        guard let deployment = try? await Deployment.find(id, on: request.db) else { return }
        
        // abort if found entry couldnt be removed
        guard (try? await deployment.delete(on: request.db)) != nil else { return }
        
        // broadcast deletion to all connected clients
        await DeploymentClients.shared.broadcast(message)
    }
}
