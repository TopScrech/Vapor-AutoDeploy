import Vapor
import Fluent

// example mist component
struct DummyRow: Mist.Component
{
    static let models: [any Model.Type] = [DummyModel.self]
    
    // define render context structure
    struct Context: Encodable
    {
        let entry: DummyModel
    }
    
    // Build context from ID
    static func makeContext(id: UUID, on db: Database) async throws -> Context?
    {
        guard let model = try await DummyModel.find(id, on: db) else { return nil }
        
        return Context(entry: model)
    }
}
