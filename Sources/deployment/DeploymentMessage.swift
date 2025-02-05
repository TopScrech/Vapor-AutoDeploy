import Vapor

enum DeploymentMessage: Codable
{
    case create(payload: Deployment)
    case update(payload: Deployment)
    case delete(payload: UUID)
    case state(payload: [Deployment])
    case message(payload: String)
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
