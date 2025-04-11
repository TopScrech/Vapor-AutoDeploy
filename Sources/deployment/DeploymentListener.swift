import Vapor
import Fluent

// database table listener
extension Deployment
{
    struct Listener: AsyncModelMiddleware
    {
        // new deployment entry created...
        func create(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            // run the middleware chain
            try await next.create(model, on: db)
            
            // construct creation message for client update over the wire
            let message = Message.create(model)
            
            // broadcast creation message to connected clients
            await DeploymentClients.shared.broadcast(message)
        }
        
        // deployment field(s) changed...
        func update(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            // run the middleware chain
            try await next.update(model, on: db)
            
            // construct update message for client update over the wire
            let message = Message.update(model)
            
            // broadcast update message to connected clients
            await DeploymentClients.shared.broadcast(message)
        }
    }
}
