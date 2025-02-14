import Vapor
import Fluent

final class DummyModel: Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels2"
    
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
            try await database.schema(Deployment.schema)
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
            try await next.update(model, on: db)
            
            // Get registered components for this model
            let components = await MistComponentRegistry.shared.getComponents(forModel: "DummyModel")
            
            // Broadcast update to each component type
            for component in components
            {
                // get the html string of component using model as context
                guard let renderer = await MistComponentRegistry.shared.renderer else { return }
                guard let html = await component.html(renderer: renderer, model: model) else { return }
                
                let message = Mist.Message.modelUpdate(
                    model: "DummyModel",
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
