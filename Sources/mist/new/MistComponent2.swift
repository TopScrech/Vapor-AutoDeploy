import Vapor
import Fluent

// Protocol specifically for models that use UUID as ID
protocol UUIDIDModel: Model
{
    typealias IDValue = UUID
}

extension Mist
{
    // Simplified component protocol - only requires models array
    protocol Component
    {
        // Component name (defaulted via extension)
        static var name: String { get }
        
        // Template name (defaulted via extension)
        static var template: String { get }
        
        // THE ONLY REQUIRED PROPERTY: array of model types
        static var models: [any UUIDIDModel.Type] { get }
    }
}

// Default implementations for all Component methods
extension Mist.Component
{
    // Default component name matches the type name
    static var name: String
    {
        String(describing: self)
    }
    
    // Default template name matches the component name
    static var template: String
    {
        String(describing: self)
    }
    
    // Generate context for a single model instance
    static func makeContext(id: UUID, on db: Database) async -> Mist.EntryContext?
    {
        var container = Mist.ModelContainer()
        var foundAny = false
        
        // Loop through all model types and try to fetch instances
        for modelType in models
        {
            // Get model type name for template reference
            let typeName = String(describing: modelType).lowercased()
            
            do
            {
                // Get the type-erased finder function and call it
                if let finder = modelType.typedFinder
                {
                    if let instance = try await finder(id, db),
                       let encodable = instance as? Encodable
                    {
                        container.add(instance as? (any Model & Encodable), for: typeName)
                        foundAny = true
                    }
                }
            }
            catch
            {
                // Just continue if there's an error with one model
                print("Error fetching model \(typeName): \(error)")
                continue
            }
        }
        
        // Only return context if at least one model was found
        return foundAny ? Mist.EntryContext(entry: container) : nil
    }
    
    // Generate context for multiple model instances
    static func makeContext(on db: Database) async -> Mist.EntriesContext?
    {
        // Make sure we have at least one model type
        guard let primaryModel = models.first else
        {
            return nil
        }
        
        do
        {
            // Use the first model type as the primary one for fetching all instances
            if let findAll = primaryModel.typedFindAll
            {
                let allPrimaryInstances = try await findAll(db)
                var entries: [Mist.ModelContainer] = []
                
                // For each primary instance, fetch related models
                for instance in allPrimaryInstances
                {
                    guard let id = instance.id as? UUID else
                    {
                        continue
                    }
                    
                    // Reuse the single context maker
                    if let singleContext = await makeContext(id: id, on: db)
                    {
                        entries.append(singleContext.entry)
                    }
                }
                
                guard !entries.isEmpty else
                {
                    return nil
                }
                
                return Mist.EntriesContext(entries: entries)
            }
        }
        catch
        {
            print("Error fetching all instances: \(error)")
        }
        
        return nil
    }
    
    // Render the component using the automatically generated context
    static func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
    {
        guard let context = await makeContext(id: id, on: db) else
        {
            return nil
        }
        
        do
        {
            let view = try await renderer.render(template, context)
            return String(buffer: view.data)
        }
        catch
        {
            print("Error rendering template: \(error)")
            return nil
        }
    }
    
    // Check if component should update for a given model
    static func shouldUpdate<M: Model>(for model: M) -> Bool
    {
        return models.contains
        { modelType in
            ObjectIdentifier(modelType) == ObjectIdentifier(M.self)
        }
    }
}

extension Mist
{
    // Type-erased component for storage in collections
    struct AnyComponent: Sendable
    {
        // Component metadata
        let name: String
        let template: String
        let models: [any Model.Type]
        
        // Type-erased functions
        private let _shouldUpdate: @Sendable (Any) -> Bool
        private let _render: @Sendable (UUID, Database, ViewRenderer) async -> String?
        
        // Create type-erased component from any concrete component type
        init<C: Component>(_ component: C.Type)
        {
            self.name = C.name
            self.template = C.template
            self.models = C.models
            
            // Capture the concrete type's methods
            self._shouldUpdate =
            { model in
                guard let model = model as? any Model else
                {
                    return false
                }
                
                return C.shouldUpdate(for: model)
            }
            
            self._render =
            { id, db, renderer in
                await C.render(id: id, on: db, using: renderer)
            }
        }
        
        // Forward calls to the captured methods
        func shouldUpdate(for model: Any) -> Bool
        {
            _shouldUpdate(model)
        }
        
        func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
        {
            await _render(id, db, renderer)
        }
    }
}
