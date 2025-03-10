import Vapor
import Fluent

// core protocol defining requirements for UI components that render database models
extension Mist
{
    protocol Component
    {
        // ensure model is a Fluent db model
        associatedtype ModelX: Fluent.Model
        // ensure context can be encoded for template rendering
        associatedtype Context: Encodable
        
        // component name used for identification
        static var name: String { get }
        // template name used for rendering
        static var template: String { get }
        
        static var models: [any Model.Type] { get }
        
        // convert model data into render context
        static func makeContext(from model: ModelX) -> Context
    }
}

extension Mist.Component
{
    // default name implementation uses type name
    static var name: String { String(describing: self) }
    // default template name matches component name
    static var template: String { String(describing: self) }
    
    // render component html using provided model and renderer
    static func render(model: ModelX, using renderer: ViewRenderer) async -> String?
    {
        let context = makeContext(from: model)
        // safely try to render template with context
        guard let buffer = try? await renderer.render(template, context).data else { return nil }
        return String(buffer: buffer)
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
        
        // type-erased render function that handles any model type
        private let _render: @Sendable (Any, ViewRenderer) async -> String?
        
        // wrap concrete component type into type-erased container
        init<C: Component>(_ component: C.Type)
        {
            self.name = C.name
            self.template = C.template
            self.models = C.models
            
            // capture concrete type info in closure
            self._render =
            { model, renderer in
                // safely cast Any back to concrete model type
                guard let typedModel = model as? C.ModelX else { return nil }
                return await C.render(model: typedModel, using: renderer)
            }
        }
        
        // type-safe render method exposed to clients
        func render(model: Any, using renderer: ViewRenderer) async -> String?
        {
            await _render(model, renderer)
        }
    }
}
