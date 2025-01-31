import Vapor

final class WebSocketManager: @unchecked Sendable
{
    static let shared = WebSocketManager()
    
    private var connections: [(id: UUID, socket: WebSocket)] = []
    
    func addConnection(id: UUID, socket: WebSocket)
    {
        connections.append((id: id, socket: socket))
    }
    
    func removeConnection(id: UUID)
    {
        connections.removeAll { $0.id == id }
    }
    
    func broadcast(_ message: WebSocketMessage) async
    {
        guard let json = message.jsonString else { return }
        
        for connection in connections
        {
            try? await connection.socket.send(json)
        }
    }
}

struct WebSocketMessage: Codable
{
    enum MessageType: String, Codable
    {
        case creation
        case update
        case message
    }
    
    let type: MessageType
    
    var deployment: Deployment? = nil
    var message: String? = nil
    
    var jsonString: String?
    {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        
        return jsonString
    }
}
