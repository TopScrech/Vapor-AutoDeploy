import Vapor
import Fluent

struct DummyRowCustom: Mist.Component
{
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    
    // Override the single component context creation
    static func makeSingleComponentContext(id: UUID, on db: Database) async -> Mist.SingleComponentContext?
    {
        // Get both model data
        guard let dummy1 = try? await DummyModel1.find(id, on: db) else { return nil }
        guard let dummy2 = try? await DummyModel2.find(id, on: db) else { return nil }
        
        // Create a model container and add models to it
        var container: Mist.ModelContainer = Mist.ModelContainer()
        container.add(dummy1, for: "dummymodel1")
        container.add(dummy2, for: "dummymodel2")
        
        // Return the single component context
        return Mist.SingleComponentContext(component: container)
    }
    
    // Override the multiple component context creation
    static func makeMultipleComponentContext(on db: Database) async -> Mist.MultipleComponentContext?
    {
        // Fetch all DummyModel1 instances
        guard let primaryModels = try? await DummyModel1.all(on: db) else { return nil }
        
        // Array to hold component data containers
        var componentContainers: [Mist.ModelContainer] = []
        
        // For each DummyModel1, find the corresponding DummyModel2
        for primaryModel in primaryModels
        {
            guard let id = primaryModel.id else { continue }
            guard let secondaryModel = try? await DummyModel2.find(id, on: db) else { continue }
            
            // Create a container for this component instance
            var container: Mist.ModelContainer = Mist.ModelContainer()
            container.add(primaryModel, for: "dummymodel1")
            container.add(secondaryModel, for: "dummymodel2")
            
            // Add to the collection
            componentContainers.append(container)
        }
        
        guard componentContainers.isEmpty == false else { return nil }
        
        // Return the multiple component context
        return Mist.MultipleComponentContext(components: componentContainers)
    }
}
