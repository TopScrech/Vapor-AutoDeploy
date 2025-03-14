import Vapor
import Fluent

extension Application
{
    // allow app to initialize mist
    func useMist()
    {
        Mist.registerComponents(on: self)
        Mist.registerMistSocket(on: self)
    }
}

extension Mist
{
    // initialize component system
    static func registerComponents(on app: Application)
    {
        Task
        {
            // configure template renderer
            await Components.shared.configure(renderer: app.leaf.renderer)
            
            // register example components
            await Components.shared.register(component: DummyRow.self, on: app)
            await Components.shared.register(component: DummyRowCustom.self, on: app)
        }
    }
}
