import Vapor
import Fluent

// mist component example
struct DummyRow: Mist.Component
{
    static let models: [any Model.Type] = [DummyModel.self]
    
    struct Context: Encodable
    {
        let entry: DummyModel
    }

    static func makeContext(id: UUID, on db: Database) async -> Context?
    {
        guard let model = try? await DummyModel.find(id, on: db) else { return nil }
        
        return Context(entry: model)
    }
}
