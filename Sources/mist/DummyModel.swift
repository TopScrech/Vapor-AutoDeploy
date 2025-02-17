import Vapor
import Fluent

final class DummyModel: Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text") var text: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(text: String)
    {
        self.text = text
    }
}

extension DummyModel
{
    static func all(on database: Database) async throws -> [DummyModel]
    {
        try await DummyModel.query(on: database)
            .sort(\.$created, .descending)
            .all()
    }
}

// database table
extension DummyModel
{
    struct Table3: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(DummyModel.schema)
                .id()
                .field("text", .string, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(DummyModel.schema).delete()
        }
    }
}

// table listener
extension DummyModel
{
    // middleware that handles model updates and triggers UI refreshes
    struct Listener: AsyncModelMiddleware
    {
        // called when model is updated in database
        func update(model: DummyModel, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            // perform database update first, propagate any errors
            try await next.update(model, on: db)
            
            // initialize logger for debugging
            let logger = Logger(label: "DummyModel.Listener")
            logger.info("change detected on a DummyModel")
            
            // get type-safe components registered for this model type
            let components = await Mist.Components.shared.getComponents(for: DummyModel.self)
            
            // safely unwrap renderer, exit if not configured
            guard let renderer = await Mist.Components.shared.getRenderer() else
            {
                logger.error("no renderer configured")
                return
            }
            
            // process each component
            for component in components
            {
                // type-safe render with error handling
                guard let html = await component.render(model: model, using: renderer) else
                {
                    logger.error("failed to render component: \(component.name)")
                    continue
                }
                
                // log rendered output for debugging
                logger.info("rendered HTML for component \(component.name): \(html)")
                
                // create update message with component info
                let message = Mist.Message.componentUpdate(
                    component: component.name,
                    action: "update",
                    id: model.id,
                    html: html
                )
                
                // broadcast to all connected clients
                await Mist.Clients.shared.broadcast(message)
            }
        }
    }
}
