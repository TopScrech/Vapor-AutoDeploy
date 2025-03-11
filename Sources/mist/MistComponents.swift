import Vapor
import Fluent

// thread-safe component registry
extension Mist
{
    actor Components
    {
        static let shared = Components()
        private init() { }

        // old storage
        // private var modelToComponents: [ObjectIdentifier: [AnyComponent]] = [:]
        
        private var components: [AnyComponent] = []
        
        private var renderer: ViewRenderer?
        
        // set template renderer
        func configure(renderer: ViewRenderer) { self.renderer = renderer }
        
        // get configured renderer
        func getRenderer() -> ViewRenderer? { return renderer }

        // Register new component type with bidirectional relationships
        func register<C: Component>(component: C.Type, on app: Application)
        {
            // abort if component name is already registered
            if components.contains(where: { $0.name == C.name }) { return }
            
            // register database listeners for component models
            for model in component.models
            {
                // check if any component is registered that also uses this model
                let isModelAlreadyRegistered = components.contains()
                {
                    $0.models.contains { ObjectIdentifier($0) == ObjectIdentifier(model) }
                }
                
                if isModelAlreadyRegistered == false
                {
                    model.createListener(on: app)
                    
                    Logger(label: "[Mist]")
                        .warning("Component '\(component.name)' created listener for model '\(String(describing: model))'")
                }
            }
            
            // add new type erased mist component to storage
            components.append(AnyComponent(component))
            
            // old implementation for reference:
            
//            // get model ID
//            let modelId = ObjectIdentifier(C.ModelX.self)
//            
//            // Get existing components for this model (if any)
//            let existingComponents = modelToComponents[modelId, default: []]
//            
//            // Check if this component is already registered by name
//            if existingComponents.contains(where: { $0.name == C.name }) { return }
//            
//            // Check if this is the first component for this model
//            let isFirstComponentForModel = existingComponents.isEmpty
//            
//            // Add the component to storage
//            modelToComponents[modelId, default: []].append(AnyComponent(component))
//            
//            // Register listener only on first component for this model
//            if isFirstComponentForModel
//            {
//                app.databases.middleware.use(Listener<C.ModelX>(), on: .sqlite)
//            }
        }
        
        // Get components that can render a specific model type
        func getComponents<M: Model>(for type: M.Type) -> [AnyComponent]
        {
            return components.filter { $0.models.contains { ObjectIdentifier($0) == ObjectIdentifier(type) } }
        }
    }
}
