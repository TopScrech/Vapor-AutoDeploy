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
    
    func broadcast(_ message: DeploymentClients.Message) async
    {
        guard let json = message.jsonString else { return }
        
        for connection in connections
        {
            try? await connection.socket.send(json)
        }
    }
}

extension DeploymentClients
{
    struct DeleteMessage: Codable
    {
        let type: String
        let deployment: DeploymentIdentifier
        
        struct DeploymentIdentifier: Codable
        {
            let id: UUID
        }
    }
}

extension DeploymentClients
{
    struct Message: Codable
    {
        enum MessageType: String, Codable
        {
            case state
            case creation
            case update
            case message
            case deletion
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
        
        func send(on ws: WebSocket) async
        {
            guard let jsonString = self.jsonString else { return }
            
            try? await ws.send(jsonString)
        }
    }
}

extension DeploymentClients.Message
{
    init(_ type: MessageType, _ message: String)
    {
        self.type = type
        self.message = message
    }
    
    init(_ type: MessageType, _ deployment: Deployment)
    {
        self.type = type
        self.deployment = deployment
    }
    
    init(_ type: MessageType, _ deployments: [Deployment])
    {
        self.type = type
        self.deployments = deployments
    }
}
