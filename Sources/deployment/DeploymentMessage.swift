import Vapor

enum DeploymentMessage: Codable
{
    case create(deployment: Deployment)
    case update(deployment: Deployment)
    case delete(id: UUID)
    case state(deployments: [Deployment])
    case message(message: String)
}

extension DeploymentMessage
{
    var jsonString: String?
    {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        
        return jsonString
    }
    
    func send(on: WebSocket) async
    {
        guard let jsonString else { return }
        
        try? await on.send(jsonString)
    }
}

extension DeploymentMessage
{
    static func create(_ deployment: Deployment) -> Self { Self.create(deployment: deployment) }
    static func update(_ deployment: Deployment) -> Self { Self.update(deployment: deployment) }
    static func delete(_ id: UUID) -> Self { Self.delete(id: id) }
    static func state(_ deployments: [Deployment]) -> Self { Self.state(deployments: deployments) }
    static func message(_ message: String) -> Self { Self.message(message: message) }
}
