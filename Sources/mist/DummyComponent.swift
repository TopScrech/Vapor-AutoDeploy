import Vapor

extension Mist
{
    struct DummyComponent: Component
    {
        let environments: String
        
        // Define the Context type for this component
        struct Context: Encodable
        {
            let property1: String
            let property2: Int
            let property3: Date
        }
        
        // Implementation of context generation
        func context(request: Request) async throws -> Context
        {
            return Context(property1: "hello", property2: 1337, property3: .now)
        }
    }
}
