@preconcurrency import Vapor
import Fluent

extension Mist
{
    // generic database model update listener
    struct Listener<M: Model>: AsyncModelMiddleware
    {
        // update callback
        func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            // perform middleware chain
            try await next.update(model, on: db)
            
            // get type-safe components registered for this model type
            let components = await Components.shared.getComponents(for: M.self)
            
            // safely unwrap renderer, exit if not configured
            guard let renderer = await Components.shared.getRenderer() else { return }
            
            // process each component
            for component in components
            {
                // type-safe render with error handling
                guard let html = await component.render(model: model, using: renderer) else { continue }
                
                // create update message with component info
                let message = Message.componentUpdate(
                    component: component.name,
                    action: "update",
                    id: model.id as? UUID,
                    html: html
                )
                
                // broadcast to all connected clients
                await Clients.shared.broadcast(message)
            }
        }
    }
}
