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
        
        // Bidirectional relationship storage
        typealias AnyModel = String
        
        private var componentToModels: [String: [AnyModel]] = [:]
        private var modelToComponents: [String: [AnyComponent]] = [:]
        
        private var renderer: ViewRenderer?
        
        // set template renderer
        func configure(renderer: ViewRenderer)
        {
            self.renderer = renderer
        }
        
        // Register new component type with bidirectional relationships
        func register<C: Component>(component: C.Type, on app: Application) where C.Model.IDValue == UUID
        {
            let modelName = String(describing: C.Model.self)
            let componentName = C.name
            
            // Check if this is the first component for this model
            let isFirstComponentForModel = modelToComponents[modelName] == nil
            
            // Update model -> components mapping
            modelToComponents[modelName, default: []].append(AnyComponent(component))
            
            // Update component -> models mapping
            componentToModels[componentName, default: []].append(modelName)
            
            // Register listener only on first component for this model
            if isFirstComponentForModel
            {
                app.databases.middleware.use(Listener<C.Model>(), on: .sqlite)
            }
        }
        
        // Get components that can render a specific model type
        func getComponents<M: Model>(for type: M.Type) -> [AnyComponent]
        {
            let modelName = String(describing: M.self)
            return modelToComponents[modelName] ?? []
        }
        
        // Get all models that a component can render
        func getModels(for componentName: String) -> [String]
        {
            return componentToModels[componentName] ?? []
        }
        
        // Check if a component exists for a model type
        func hasComponents<M: Model>(for type: M.Type) -> Bool
        {
            let modelName = String(describing: M.self)
            return modelToComponents[modelName]?.isEmpty == false
        }
        
        // Check if a model type has a specific component
        func hasComponent<M: Model>(named componentName: String, for type: M.Type) -> Bool
        {
            let modelName = String(describing: M.self)
            return componentToModels[componentName]?.contains(modelName) == true
        }
        
        // Get configured renderer
        func getRenderer() -> ViewRenderer?
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
