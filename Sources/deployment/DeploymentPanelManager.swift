import Vapor

final class DeploymentPanelManager: @unchecked Sendable
{
    static let shared = DeploymentPanelManager()
    
    private var connections: [(id: UUID, socket: WebSocket)] = []
    
    func add(connection id: UUID, socket: WebSocket)
    {
        connections.append((id: id, socket: socket))
    }
    
    func remove(connection id: UUID)
    {
        connections.removeAll { $0.id == id }
    }
    
    func broadcast(_ message: DeploymentPanalMessage) async
    {
        guard let json = message.jsonString else { return }
        
        for connection in connections
        {
            try? await connection.socket.send(json)
        }
    }
}

struct DeploymentPanalMessage: Codable
{
    enum MessageType: String, Codable
    {
        case state
        case creation
        case update
        case message
    }
    
    let type: MessageType
    
    var deployment: Deployment? = nil
    var deployments: [Deployment]? = nil
    var message: String? = nil
    
    var jsonString: String?
    {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        
        return jsonString
    }
}
