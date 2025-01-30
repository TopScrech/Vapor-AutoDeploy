import Vapor
import Fluent

// Message structure for WebSocket communicationn
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
}

struct DeploymentMiddleware: AsyncModelMiddleware
{
    func create(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        try await next.create(model, on: db)
        
        let message = WebSocketMessage(type: .creation, deployment: model)
        let jsonData = try JSONEncoder().encode(message)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        await WebSocketManager.shared.broadcast(jsonString)
    }
    
    func update(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        let message = WebSocketMessage(type: .update, deployment: model)
        let jsonData = try JSONEncoder().encode(message)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        await WebSocketManager.shared.broadcast(jsonString)
        
        try await next.update(model, on: db)
    }
}
