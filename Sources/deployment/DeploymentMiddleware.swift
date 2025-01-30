import Vapor
import Fluent

// Message structure for WebSocket communication
struct WebSocketMessage: Codable
{
    enum MessageType: String, Codable
    {
        case creation
        case update
    }
    
    let type: MessageType
    let deployment: Deployment
}

struct DeploymentMiddleware: AsyncModelMiddleware
{
    func create(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        try await next.create(model, on: db)
        
        let message = WebSocketMessage(
            type: .creation,
            deployment: model
        )
        
        let jsonData = try JSONEncoder().encode(message)
        
        if let jsonString = String(data: jsonData, encoding: .utf8)
        {
            await WebSocketManager.shared.broadcast(jsonString)
        }
    }
    
//    func update(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
//    {
//        try await next.update(model, on: db)
//        
//        let message = WebSocketMessage(
//            type: .update,
//            deployment: model
//        )
//        
//        let jsonData = try JSONEncoder().encode(message)
//        
//        if let jsonString = String(data: jsonData, encoding: .utf8)
//        {
//            await WebSocketManager.shared.broadcast(jsonString)
//        }
//    }
}
