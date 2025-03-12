import Vapor
import Fluent

extension Mist
{
    // thread-safe component registry
    actor Components
    {
        static let shared = Components()
        private init() { }
        
        // type-erased mist component storage
        private var components: [AnyComponent] = []

        // template renderer
        private var renderer: ViewRenderer?

        // type-safe mist component registration
        func register<C: Component>(component: C.Type, on app: Application)
        {
            // abort if component name is already registered
            if components.contains(where: { $0.name == C.name }) { return }
            
            // register database listeners for component models
            for model in component.models
            {
                // search for component using this model
                let isModelUsed = components.contains()
                {
                    $0.models.contains { ObjectIdentifier($0) == ObjectIdentifier(model) }
                }
                
                // if this model is not yet used
                if isModelUsed == false
                {
                    // register db model listener middleware
                    model.createListener(on: app)
                    
                    Logger(label: "[Mist]")
                        .warning("Component '\(component.name)' created listener for model '\(String(describing: model))'")
                }
            }
            
            // add new type erased mist component to storage
            components.append(AnyComponent(component))
        }
        
        // retrieve all components that use a specific model
        func getComponents<M: Model>(for type: M.Type) -> [AnyComponent]
        {
            return components.filter { $0.models.contains { ObjectIdentifier($0) == ObjectIdentifier(type) } }
        }

        // set template renderer
        func configure(renderer: ViewRenderer) { self.renderer = renderer }
        // get template renderer
        func getRenderer() -> ViewRenderer? { return renderer }
    }
}
