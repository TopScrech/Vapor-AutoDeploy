import Vapor
import Fluent

// core protocol defining requirements for UI components that render database models
extension Mist
{
    protocol Component
    {
        // ensure context can be encoded for template rendering
        associatedtype Context: Encodable
        
        // component name used for identification
        static var name: String { get }
        // template name used for rendering
        static var template: String { get }
        
        static var models: [any Model.Type] { get }
        
        // Build context from ID instead of direct model
        static func makeContext(id: UUID, on db: Database) async throws -> Context?

        // Determine if this component should update for this model
        static func shouldUpdate<M: Model>(for model: M) -> Bool
    }
}

extension Mist.Component
{
    // default name implementation uses type name
    static var name: String { String(describing: self) }
    // default template name matches component name
    static var template: String { String(describing: self) }
    
    static func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
    {
        do
        {
            guard let context = try await makeContext(id: id, on: db) else { return nil }
            let buffer = try await renderer.render(template, context).data
            return String(buffer: buffer)
        }
        catch { return nil }
    }
    
    // Default implementation for shouldUpdate
    static func shouldUpdate<M: Model>(for model: M) -> Bool
    {
        return models.contains { ObjectIdentifier($0) == ObjectIdentifier(M.self) }
    }
}

// type erasure wrapper to store different component types together
extension Mist
{
    struct AnyComponent: Sendable
    {
        let name: String
        let template: String
        let models: [any Model.Type]
        
        private let _shouldUpdate: @Sendable (Any) -> Bool
        private let _render: @Sendable (UUID, Database, ViewRenderer) async -> String?
        
        // wrap concrete component type into type-erased container
        init<C: Component>(_ component: C.Type)
        {
            self.name = C.name
            self.template = C.template
            self.models = C.models
            
            self._shouldUpdate =
            { model in
                guard let type = model as? any Model else { return false }
                return C.shouldUpdate(for: type)
            }
            
            self._render =
            { id, db, renderer in
                await C.render(id: id, on: db, using: renderer)
            }
        }
        
        // Exposed type-safe methods
        func shouldUpdate(for model: Any) -> Bool
        {
            _shouldUpdate(model)
        }
        
        func render(id: UUID, db: Database, using renderer: ViewRenderer) async -> String?
        {
            await _render(id, db, renderer)
        }
    }
}
