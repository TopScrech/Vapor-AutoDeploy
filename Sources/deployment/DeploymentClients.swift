import Vapor

actor DeploymentClients
{
    static let shared = DeploymentClients()
    
    private var connections: [(id: UUID, socket: WebSocket)] = []
    
    func add(connection id: UUID, socket: WebSocket)
    {
        connections.append((id: id, socket: socket))
    }
    
    func remove(connection id: UUID)
    {
        connections.removeAll { $0.id == id }
    }
    
    func broadcast(_ message: Deployment.Message) async
    {
        guard let payload = message.jsonString else { return }
        
        for connection in connections
        {
            try? await connection.socket.send(payload)
        }
    }
}
