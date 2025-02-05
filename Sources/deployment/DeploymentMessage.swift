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
    func send(on: WebSocket) async
    {
        if let jsonString { try? await on.send(jsonString) }
    }
    
    var jsonString: String?
    {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        
        return jsonString
    }
}

// convenience message factories
extension Deployment.Message
{
    static func create(_ deployment: Deployment) -> Self { Self.create(deployment: deployment) }
    static func update(_ deployment: Deployment) -> Self { Self.update(deployment: deployment) }
    static func delete(_ id: UUID) -> Self { Self.delete(id: id) }
    static func state(_ deployments: [Deployment]) -> Self { Self.state(deployments: deployments) }
    static func message(_ message: String) -> Self { Self.message(message: message) }
}
