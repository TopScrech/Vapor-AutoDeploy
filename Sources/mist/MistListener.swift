@preconcurrency import Vapor
import Fluent

extension Model
{
    static func createListener(on app: Application)
    {
        app.databases.middleware.use(Mist.Listener<Self>(), on: .sqlite)
    }
}

extension Mist
{
    // generic database model update listener
    struct Listener<M: Model>: AsyncModelMiddleware
    {
        let logger = Logger(label: "[Mist]")
        
        // update callback
        func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            logger.warning("Listener for model '\(String(describing: model))' was triggered.")

            // perform middleware chain
            try await next.update(model, on: db)
            
            // Ensure we have a UUID
            guard let modelID = model.id as? UUID else { return }
            
            // get type-safe components registered for this model type
            let components = await Components.shared.getComponents(for: M.self)
            
            // safely unwrap renderer
            guard let renderer = await Components.shared.getRenderer() else { return }
            
            // process each component
            for component in components
            {
                // Only update if component says it should
                guard component.shouldUpdate(for: model) else { continue }
                
                // render using ID and database
                guard let html = await component.render(id: modelID, db: db, using: renderer) else { continue }
                
                // create update message with component data
                let message = Message.componentUpdate(
                    component: component.name,
                    action: "update",
                    id: modelID,
                    html: html
                )
                
                // broadcast to all connected clients
                await Clients.shared.broadcast(message)
                
                logger.warning("Broadcasting Component '\(component.name)'")
            }
        }
    }
}
