import Vapor
import Fluent

// Message structure for WebSocket communication
struct WebSocketMessage: Codable
{
    enum MessageType: Codable
    {
        case creation(Deployment)
        case update(Deployment)
        case message(String)
    }
    
    let type: MessageType
    
    var typeString: String
    {
        switch type
        {
            case .creation(let deployment): "creation"
            case .update(let deployment): "update"
            case .message(let message): "message"
        }
    }
}

struct DeploymentMiddleware: AsyncModelMiddleware
{
    func create(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        try await next.create(model, on: db)
        
        let message = WebSocketMessage(type: .creation(model))
        
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
