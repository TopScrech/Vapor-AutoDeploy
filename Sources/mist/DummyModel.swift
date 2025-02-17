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
    struct Listener: AsyncModelMiddleware
    {
        func update(model: DummyModel, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            // First perform the database update
            try await next.update(model, on: db)
            
            let logger = Logger(label: "DummyModel.Listener")
            logger.info("change detected on a DummyModel")
            
            // Fetch components that are registered for DummyModel type
            let components = await Mist.Components.shared.getComponents(for: DummyModel.self)
            
            // Get the renderer from the components registry
            guard let renderer = await Mist.Components.shared.getRenderer() else
            {
                logger.error("no renderer configured")
                return
            }
            
            for component in components
            {
                // Render the component using the type-erased render method
                guard let html = await component.render(model: model, using: renderer) else
                {
                    logger.error("failed to render component: \(component.name)")
                    continue
                }
                
                logger.info("rendered HTML for component \(component.name): \(html)")
                
                // Construct and broadcast the update message
                let message = Mist.Message.componentUpdate(
                    component: component.name,
                    action: "update",
                    id: model.id,
                    html: html
                )
                
                await Mist.Clients.shared.broadcast(message)
            }
        }
    }
}
