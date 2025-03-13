import Vapor
import Fluent

// mist component example
struct DummyRow: Mist.Component
{
    static let models: [any Model.Type] = [DummyModel1.self, DummyModel2.self]
    
    struct ContextData: Encodable
    {
        let dummy1: DummyModel1
        let dummy2: DummyModel2
    }
    
    static func makeContext(id: UUID, on db: Database) async -> SingleContext?
    {
        // get both model data
        guard let dummy1 = try? await DummyModel1.find(id, on: db) else { return nil }
        guard let dummy2 = try? await DummyModel2.find(id, on: db) else { return nil }
        
        // return joined context
        return SingleContext(entry: ContextData(dummy1: dummy1, dummy2: dummy2))
    }
    
    static func makeContext(on db: Database) async -> MultipleContext?
    {
        // Fetch all DummyModel instances
        guard let primaryModels = try? await DummyModel1.all(on: db) else { return nil }
        
        // Array to hold combined model data
        var joinedModels: [ContextData] = []
        
        // For each DummyModel, find the corresponding DummyModel2
        for primaryModel in primaryModels
        {
            guard let id = primaryModel.id else { continue }
            
            // Find matching DummyModel2 with the same ID
            guard let secodaryModel = try? await DummyModel2.find(id, on: db) else { continue }
            
            // Add combined data
            joinedModels.append(ContextData(dummy1: primaryModel, dummy2: secodaryModel))
        }
        
        guard joinedModels.isEmpty == false else { return nil }
        
        return MultipleContext(entries: joinedModels)
    }
}
