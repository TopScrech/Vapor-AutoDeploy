import Vapor
import Fluent

// thread-safe component registry
extension Mist
{
    actor Components
    {
        static let shared = Components()
        private init() { }

        private var modelToComponents: [ObjectIdentifier: [AnyComponent]] = [:]
        
        private var renderer: ViewRenderer?
        
        // set template renderer
        func configure(renderer: ViewRenderer) { self.renderer = renderer }
        
        // get configured renderer
        func getRenderer() -> ViewRenderer? { return renderer }

        // Register new component type with bidirectional relationships
        func register<C: Component>(component: C.Type, on app: Application) where C.Model.IDValue == UUID
        {
            // get model ID
            let modelId = ObjectIdentifier(C.Model.self)
            
            // Get existing components for this model (if any)
            let existingComponents = modelToComponents[modelId, default: []]
            
            // Check if this component is already registered by name
            if existingComponents.contains(where: { $0.name == C.name }) { return }
            
            // Check if this is the first component for this model
            let isFirstComponentForModel = existingComponents.isEmpty
            
            // Add the component to storage
            modelToComponents[modelId, default: []].append(AnyComponent(component))
            
            // Register listener only on first component for this model
            if isFirstComponentForModel
            {
                app.databases.middleware.use(Listener<C.Model>(), on: .sqlite)
            }
        }
        
        // Get components that can render a specific model type
        func getComponents<M: Model>(for type: M.Type) -> [AnyComponent]
        {
            return modelToComponents[ObjectIdentifier(M.self)] ?? []
        }
    }
}
