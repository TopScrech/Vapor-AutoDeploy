import Vapor
import Fluent

//extension Mist
//{
//    // protocol to render db model(s) into html mist components
//    protocol Component
//    {
//        // component name used for identification
//        static var name: String { get }
//        
//        // template name used for rendering
//        static var template: String { get }
//        
//        // array of model types this component reacts to
//        static var models: [any Model.Type] { get }
//        
//        // encodable component model data
//        associatedtype ContextData: Encodable
//        
//        // context structure for single component
//        typealias SingleContext = SingleEntryContext<ContextData>
//        
//        // context structure for multiple components
//        typealias MultipleContext = MultipleEntriesContext<ContextData>
//                
//        // component for given model ID
//        static func makeContext(id: UUID, on db: Database) async -> SingleContext?
//        
//        // all components
//        static func makeContext(on db: Database) async -> MultipleContext?
//    }
//    
//    // generic single entry context
//    struct SingleEntryContext<T: Encodable>: Encodable
//    {
//        let entry: T
//    }
//    
//    // generic multiple entries context
//    struct MultipleEntriesContext<T: Encodable>: Encodable
//    {
//        let entries: [T]
//    }
//}
//
//extension Mist.Component
//{
//    // default name implementation uses type name
//    static var name: String { String(describing: self) }
//    
//    // default template name matches component name
//    static var template: String { String(describing: self) }
//    
//    // renders the components using model data in appropriate leaf context
//    static func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
//    {
//        guard let context = await makeContext(id: id, on: db) else { return nil }
//        guard let buffer = try? await renderer.render(template, context).data else { return nil }
//        
//        return String(buffer: buffer)
//    }
//    
//    // checks if component should update when this model changes
//    static func shouldUpdate<M: Model>(for model: M) -> Bool
//    {
//        return models.contains { ObjectIdentifier($0) == ObjectIdentifier(M.self) }
//    }
//}

//extension Mist
//{
//    // type erasure wrapper to store different component types together
//    struct AnyComponent: Sendable
//    {
//        let name: String
//        let template: String
//        let models: [any Model.Type]
//        
//        private let _shouldUpdate: @Sendable (Any) -> Bool
//        private let _render: @Sendable (UUID, Database, ViewRenderer) async -> String?
//        
//        // wrap concrete component type into type-erased container
//        init<C: Component>(_ component: C.Type)
//        {
//            self.name = C.name
//            self.template = C.template
//            self.models = C.models
//            
//            self._shouldUpdate =
//            { model in
//                guard let type = model as? any Model else { return false }
//                return C.shouldUpdate(for: type)
//            }
//            
//            self._render =
//            { id, db, renderer in
//                await C.render(id: id, on: db, using: renderer)
//            }
//        }
//        
//        func shouldUpdate(for model: Any) -> Bool
//        {
//            _shouldUpdate(model)
//        }
//        
//        func render(id: UUID, db: Database, using renderer: ViewRenderer) async -> String?
//        {
//            await _render(id, db, renderer)
//        }
//    }
//}
