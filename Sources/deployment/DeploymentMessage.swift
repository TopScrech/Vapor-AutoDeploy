import Vapor

enum DeploymentMessage: Codable
{
    case create(deployment: Deployment)
    case update(deployment: Deployment)
    case delete(id: UUID)
    case state(deployments: [Deployment])
    case message(message: String)
    
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

func blob()
{
    let create = DeploymentMessage.create(deployment: Deployment(status: "running", message: "Hello World"))
}
