import Vapor

extension Mist
{
    struct DummyComponent: Component
    {        
        let environments = "TestEnvironment"
        
        // Define the Context type for this component
        struct Context: Encodable
        {
            let property1: String
            let property2: Int
            let property3: Date
        }
        
        // Implementation of context generation
        func context() -> Context
        {
            return Context(property1: "hello", property2: 1337, property3: .now)
        }
    }
    
    struct ChildComponent: Component
    {
        let environments = "TestEnvironment"
        
        // Define the Context type for this component
        struct Context: Encodable
        {
            let child1: String
            let child2: Int
        }
        
        // Implementation of context generation
        func context() -> Context
        {
            return Context(child1: "world", child2: 4133)
        }
    }
}
