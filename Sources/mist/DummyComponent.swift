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
            let child: ChildContext
            
            struct ChildContext: Encodable
            {
                let child1: String
                let child2: Int
            }
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
    }
}
