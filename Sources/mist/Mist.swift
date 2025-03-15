import Vapor
import Fluent

extension Mist
{
    // initialize component system
    static func registerComponents(using config: Configuration) throws
    {
        // get app reference
        Task
        {
            // Configure components with the configuration
//            await Components.shared.configure(with: configuration)
            
            // Register example components
            try await Components.shared.register(component: DummyRow.self, using: config)
            try await Components.shared.register(component: DummyRowCustom.self, using: config)
        }
    }
}
