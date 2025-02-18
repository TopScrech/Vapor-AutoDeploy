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
        private var components: [String: [AnyComponent]] = [:]
        private var renderer: ViewRenderer?
        
        // set template renderer
        func configure(renderer: ViewRenderer)
        {
            self.renderer = renderer
        }
        
        // register new component type
        func register<C: Component>(component: C.Type, on app: Application) where C.Model.IDValue == UUID
        {
            let modelName = String(describing: C.Model.self)
            
            // If this is the first component for this model type,
            // we need to register the listener
            let isFirstComponentForModel = components[modelName] == nil
            
            // Add the component
            components[modelName, default: []].append(AnyComponent(component))
            
            // Register listener only on first component for this model
            if isFirstComponentForModel
            {
                app.databases.middleware.use(Listener<C.Model>(), on: .sqlite)
            }
        }
        
        // get components that can render given model type
        func getComponents<M: Model>(for type: M.Type) -> [AnyComponent]
        {
            let modelName = String(describing: M.self)
            return components[modelName] ?? []
        }
        
        // get configured renderer
        func getRenderer() async -> ViewRenderer?
        {
            return renderer
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
            await Components.shared.configure(renderer: app.leaf.renderer)
            
            // register example component
            await Components.shared.register(component: DummyRow.self, on: app)
        }
    }
}
