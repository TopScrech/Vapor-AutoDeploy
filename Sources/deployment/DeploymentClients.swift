import Vapor

// thread-safe client registry
actor DeploymentClients
{
    // singleton pattern
    static let shared = DeploymentClients()
    private init() { }
    
    // store clients as array of named tuples
    private var clients: [(id: UUID, socket: WebSocket)] = []
    
    // adds a new client to registry
    func add(client id: UUID, socket: WebSocket)
    {
        clients.append((id: id, socket: socket))
    }
    
    // removes client from registry
    func remove(client id: UUID)
    {
        clients.removeAll { $0.id == id }
    }
    
    // broadcast messages to connected clients
    func broadcast(_ message: Deployment.Message) async
    {
        guard let payload = message.jsonString else { return }
        
        for client in clients
        {
            try? await client.socket.send(payload)
        }
    }
}
