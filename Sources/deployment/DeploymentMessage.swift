import Vapor

enum DeploymentMessage: Codable
{
    case create(_ payload: Deployment)
    case update(_ payload: Deployment)
    case delete(_ payload: UUID)
    case state(_ payload: [Deployment])
    case message(_ payload: String)
    
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
    let create = DeploymentMessage.create(Deployment(status: "running", message: "Hello World"))
}
