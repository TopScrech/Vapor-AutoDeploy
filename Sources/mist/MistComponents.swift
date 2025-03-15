import Vapor
import Fluent

extension Mist
{
    enum ConfigurationError: Error
    {
        case componentExists(name: String)
        case applicationMissing
        case databaseMissing
        case noConfig
    }
}

extension Mist
{
    // thread-safe component registry
    actor Components
    {
        static let shared = Components()
        private init() { }
        
        // type-erased mist component storage
        private var components: [AnyComponent] = []

        // config reference
        // private var config: Mist.Configuration?

        // type-safe mist component registration
        func register<C: Component>(component: C.Type, using config: Mist.Configuration) throws
        {
            // abort if component name is already registered
            guard components.contains(where: { $0.name == C.name }) == false else { throw ConfigurationError.componentExists(name: C.name) }
            
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
                    try model.createListener(using: config)
                    
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
//        func configure(with config: Mist.Configuration) { self.config = config }
        
        // Get database ID from configuration
//        func getDatabaseID() -> DatabaseID? { return config?.databaseID }

        // get templater enderer through configuration
//        func getRenderer() -> ViewRenderer? { return config?.application?.leaf.renderer }
    }
}
