import Vapor
import Fluent

// mist component example
struct DummyRow: Mist.Component
{
    static let models: [any Model.Type] = [DummyModel.self, DummyModel2.self]
    
    struct EntryData: Encodable
    {
        let dummy1: DummyModel
        let dummy2: DummyModel2
    }
    
    struct Context: Encodable
    {
        let entry: EntryData
    }
    
    static func makeContext(id: UUID, on db: Database) async -> Context?
    {
        guard let dummy1 = try? await DummyModel.find(id, on: db) else { return nil }
        guard let dummy2 = try? await DummyModel2.find(id, on: db) else { return nil }
        
        return Context(entry: EntryData(dummy1: dummy1, dummy2: dummy2))
    }
}
