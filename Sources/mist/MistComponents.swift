import Vapor
import Fluent

// thread-safe component registry
extension Mist
{
    actor Components
    {
        // singleton instance
        static let shared = Components()
        private init() { }
        
        // store components by model type name
        private var components: [String: [Mist.AnyComponent]] = [:]
        private var renderer: ViewRenderer?
        
        // set template renderer
        func configure(renderer: ViewRenderer)
        {
            self.renderer = renderer
        }
        
        // register new component type
        func register<C: Mist.Component>(_ component: C.Type)
        {
            let modelName = String(describing: C.Model.self)
            components[modelName, default: []].append(Mist.AnyComponent(component))
        }
        
        // get components that can render given model type
        func getComponents<M: Model>(for type: M.Type) -> [Mist.AnyComponent]
        {
            let modelName = String(describing: M.self)
            return components[modelName] ?? []
        }
        
        // get configured renderer
        func getRenderer() -> ViewRenderer?
        {
            renderer
        }
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
            await Mist.Components.shared.configure(renderer: app.leaf.renderer)
            
            // register example component
            await Mist.Components.shared.register(DummyRow.self)
        }
    }
}
