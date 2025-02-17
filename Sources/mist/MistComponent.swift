import Vapor
import Fluent

// core protocol defining requirements for UI components that render database models
protocol MistComponent
{
    // ensure model is a Fluent db model
    associatedtype Model: Fluent.Model
    // ensure context can be encoded for template rendering
    associatedtype Context: Encodable
    
    // component name used for identification
    static var name: String { get }
    // template name used for rendering
    static var template: String { get }
    
    // convert model data into render context
    static func makeContext(from model: Model) -> Context
}

extension MistComponent
{
    // default name implementation uses type name
    static var name: String { String(describing: self) }
    // default template name matches component name
    static var template: String { String(describing: self) }
    
    // render component html using provided model and renderer
    static func render(model: Model, using renderer: ViewRenderer) async -> String?
    {
        let context = makeContext(from: model)
        // safely try to render template with context
        guard let buffer = try? await renderer.render(template, context).data else { return nil }
        return String(buffer: buffer)
    }
}

// type erasure wrapper to store different component types together
struct AnyComponent
{
    let name: String
    let template: String
    
    // type-erased render function that handles any model type
    private let _render: (Any, ViewRenderer) async -> String?
    
    // wrap concrete component type into type-erased container
    init<C: MistComponent>(_ component: C.Type)
    {
        self.name = C.name
        self.template = C.template
        
        // capture concrete type info in closure
        self._render =
        { model, renderer in
            // safely cast Any back to concrete model type
            guard let typedModel = model as? C.Model else { return nil }
            return await C.render(model: typedModel, using: renderer)
        }
    }
    
    // type-safe render method exposed to clients
    func render(model: Any, using renderer: ViewRenderer) async -> String?
    {
        await _render(model, renderer)
    }
}

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
        func register<C: MistComponent>(_ component: C.Type)
        {
            let modelName = String(describing: C.Model.self)
            components[modelName, default: []].append(AnyComponent(component))
        }
        
        // get components that can render given model type
        func getComponents<M: Model & Content>(for type: M.Type) -> [AnyComponent]
        {
            let modelName = String(describing: M.self)
            return components[modelName] ?? []
        }
        
        // get configured renderer
        func getRenderer() -> ViewRenderer?
        {
            renderer
        }
    }
}

// example component implementation
struct DummyRow: MistComponent
{
    // specify model type this component renders
    typealias Model = DummyModel
    
    // define render context structure
    struct Context: Encodable
    {
        let entry: DummyModel
    }
    
    // convert model to render context
    static func makeContext(from model: Model) -> Context
    {
        Context(entry: model)
    }
}

extension Mist
{
    // initialize component system
    static func configureComponents(_ app: Application)
    {
        Task
        {
            // configure template renderer
            await Mist.Components.shared.configure(renderer: app.leaf.renderer)
            
            // register example component
            await Mist.Components.shared.register(DummyRow.self)
        }
    }
}
