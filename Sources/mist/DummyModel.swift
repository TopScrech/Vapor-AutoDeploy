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

extension DummyModel
{
    struct Listener: AsyncModelMiddleware
    {
        private let logger = Logger(label: "DummyModel.Listener")
        
        func update(model: DummyModel, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            try await next.update(model, on: db)
            
            logger.info("Model update detected: \(model.id?.uuidString ?? "unknown")")
            
            let components = await Mist.Components.shared.getComponents(for: DummyModel.self)
            
            guard !components.isEmpty
            else
            {
                logger.warning("No components registered for DummyModel")
                return
            }
            
            guard let renderer = await Mist.Components.shared.renderer
            else
            {
                logger.error("Renderer not configured")
                return
            }
            
            for componentType in components
            {
                do
                {
                    // We can now safely cast to the concrete component type
                    guard let concreteComponent = componentType as? any MistComponent<DummyModel>.Type
                    else
                    {
                        logger.error("Component type mismatch")
                        continue
                    }
                    
                    let html = try await concreteComponent.render(model: model, using: renderer)
                    
                    logger.debug("Generated HTML for component: \(concreteComponent.name.rawValue)")
                    
                    let message = Mist.Message.componentUpdate(
                        component: concreteComponent.name.rawValue,
                        action: "update",
                        id: model.id,
                        html: html
                    )
                    
                    await Mist.Clients.shared.broadcast(message)
                }
                catch
                {
                    logger.error("Failed to process component: \(error.localizedDescription)")
                    continue
                }
            }
        }
    }
}
