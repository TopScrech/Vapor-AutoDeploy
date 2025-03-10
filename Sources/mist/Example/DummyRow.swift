import Vapor
import Fluent

// example mist component
struct DummyRow: Mist.Component
{
    static let models: [any Fluent.Model.Type] = [DummyModel.self]
        
    // specify model type this component renders
    typealias ModelX = DummyModel
    
    // define render context structure
    struct Context: Encodable
    {
        let entry: DummyModel
    }
    
    // convert model to render context
    static func makeContext(from model: ModelX) -> Context
    {
        Context(entry: model)
    }
}
