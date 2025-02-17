import Vapor
import Fluent

// MARK: - Core Protocol
protocol MistComponent
{
    associatedtype Model: Fluent.Model & Content
    associatedtype Context: Encodable
    
    static var name: String { get }
    static var template: String { get }
    
    static func makeContext(from model: Model) -> Context
}

extension MistComponent
{
    static var name: String { String(describing: self) }
    static var template: String { String(describing: self) }
    
    static func render(model: Model, using renderer: ViewRenderer) async -> String?
    {
        let context = makeContext(from: model)
        guard let buffer = try? await renderer.render(template, context).data else { return nil }
        return String(buffer: buffer)
    }
}

// MARK: - Type Erased Component
struct AnyComponent
{
    let name: String
    let template: String
    
    private let _render: (Any, ViewRenderer) async -> String?
    
    init<C: MistComponent>(_ component: C.Type)
    {
        self.name = C.name
        self.template = C.template
        
        self._render =
        { model, renderer in
            guard let typedModel = model as? C.Model else { return nil }
            return await C.render(model: typedModel, using: renderer)
        }
    }
    
    func render(model: Any, using renderer: ViewRenderer) async -> String?
    {
        await _render(model, renderer)
    }
}

// MARK: - Registry
extension Mist
{
    actor Components
    {
        static let shared = Components()
        private init() { }
        
        private var components: [String: [AnyComponent]] = [:]
        private var renderer: ViewRenderer?
        
        func configure(renderer: ViewRenderer)
        {
            self.renderer = renderer
        }
        
        func register<C: MistComponent>(_ component: C.Type)
        {
            let modelName = String(describing: C.Model.self)
            components[modelName, default: []].append(AnyComponent(component))
        }
        
        func getComponents<M: Model & Content>(for type: M.Type) -> [AnyComponent]
        {
            let modelName = String(describing: M.self)
            return components[modelName] ?? []
        }
        
        func getRenderer() -> ViewRenderer?
        {
            renderer
        }
    }
}

// MARK: - Example Implementation
struct DummyRow: MistComponent
{
    // The model this component renders
    typealias Model = DummyModel
    
    // Component's specific context
    struct Context: Encodable
    {
        let entry: DummyModel
    }
    
    static func makeContext(from model: Model) -> Context
    {
        Context(entry: model)
    }
}

extension Mist
{
    // run when server app initializes
    static func configureComponents(_ app: Application)
    {
        Task
        {
            await Mist.Components.shared.configure(renderer: app.leaf.renderer)
            
            await Mist.Components.shared.register(DummyRow.self)
        }
    }
}
