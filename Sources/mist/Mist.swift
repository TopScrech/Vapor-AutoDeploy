import Vapor
import Fluent

struct Mist
{
    static func configure(using config: Mist.Configuration)
    {
        Mist.registerComponents(using: config)
        Mist.registerMistSocket(on: config.app)
    }
}

extension Mist
{
    // initialize component system
    static func registerComponents(using config: Configuration)
    {
        // Register example components
        Task
        {
            await Components.shared.register(component: DummyRow.self, using: config)
            await Components.shared.register(component: DummyRowCustom.self, using: config)
        }
    }
}
