import Vapor
import Fluent
import Mist

struct DummyRowCustom: Mist.Component
{
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    
    // override the single component context creation
    static func makeContext(of componentID: UUID, in db: Database) async -> Mist.SingleComponentContext?
    {
        // get both model data
        guard let dummy1 = try? await DummyModel1.find(componentID, on: db) else { return nil }
        guard let dummy2 = try? await DummyModel2.find(componentID, on: db) else { return nil }
        
        // create a model container and add models to it
        var container = Mist.ModelContainer()
        container.add(dummy1, for: "dummymodel1")
        container.add(dummy2, for: "dummymodel2")
        
        // return the single component context
        return Mist.SingleComponentContext(component: container)
    }
    
    // override the multiple component context creation
    static func makeMultipleComponentContext(on db: Database) async -> Mist.MultipleComponentContext?
    {
        // fetch all DummyModel1 instances
        guard let primaryModels = try? await DummyModel1.all(on: db) else { return nil }
        
        // array to hold component data containers
        var componentContainers: [Mist.ModelContainer] = []
        
        // for each DummyModel1, find the corresponding DummyModel2
        for primaryModel in primaryModels
        {
            guard let id = primaryModel.id else { continue }
            guard let secondaryModel = try? await DummyModel2.find(id, on: db) else { continue }
            
            // create a container for this component instance
            var container = Mist.ModelContainer()
            container.add(primaryModel, for: "dummymodel1")
            container.add(secondaryModel, for: "dummymodel2")
            
            // add to the collection
            componentContainers.append(container)
        }
        
        // abort if empty
        guard componentContainers.isEmpty == false else { return nil }
        
        // return the multiple component context
        return Mist.MultipleComponentContext(components: componentContainers)
    }
}
