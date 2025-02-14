import Vapor
import Fluent

final class DummyModel: Model, Content, @unchecked Sendable
{
    static let schema = "TestModel"
    
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
    struct Table: AsyncMigration
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
        // react to DummyModel entry updates
        func update(model: DummyModel, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            try await next.update(model, on: db)
            
            // construct update message
            let message = Mist.Message.modelUpdate(model: "DummyModel", action: "update", id: model.id, payload: model)
            
            // send update message to all DummyModel subscribers
            await Mist.Clients.shared.broadcast(message)
        }
    }
}
