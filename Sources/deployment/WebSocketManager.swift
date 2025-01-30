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
    
    func broadcast(_ message: String) async
    {
        for connection in connections
        {
            try? await connection.socket.send(message)
        }
    }
}
