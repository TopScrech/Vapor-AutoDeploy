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
            try await next.update(model, on: db)
            
            let logger = Logger(label: "DummyModel.Listener")
            logger.info("change detected on a DummyModel")
            
            // fetch components that are bound to DummyModel
            let components = await Mist.Components.shared.getComponents(forModel: "DummyModel")
            
            for component in components
            {
                // render html string of component using updated db entry as context
                guard let renderer = await Mist.Components.shared.renderer else { return }
                guard let html = await component.html(renderer: renderer, model: model) else { return }
                
                let logger = Logger(label: "DummyModel.Listener")
                logger.info("following html will be sent to subscribers: \(html)")
                
                // construct message
                let message = Mist.Message.componentUpdate(
                    component: component.name,
                    action: "update",
                    id: model.id,
                    html: html
                )
                
                // send component update message to all subscribers of db model
                await Mist.Clients.shared.broadcast(message)
            }
        }
    }
}
