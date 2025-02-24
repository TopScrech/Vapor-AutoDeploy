import Vapor
import Fluent

struct Component
{
    let name: String
    let template: String
    let models: [any Fluent.Model.Type]
    let makeContext: ([any Fluent.Model]) -> Encodable?
    
    init(name: String, models: [any Fluent.Model.Type], makeContext: @escaping ([any Fluent.Model]) -> Encodable?)
    {
        self.name = name
        self.template = name
        self.models = models
        self.makeContext = makeContext
    }
}

actor Components
{
    static let shared = Components()
    private init() { }
    
    private var components: [Component] = []
    private var renderer: ViewRenderer?
    
    func configure(renderer: ViewRenderer) { self.renderer = renderer }
    func add(_ component: Component) { components.append(component) }
    
    func render(name: String, models: [any Fluent.Model]) async throws -> String?
    {
        guard let renderer else { return nil }
        guard let component = components.first(where: { $0.name == name }) else { return nil }
        guard let context = component.makeContext(models) else { return nil }
        
        guard let buffer = try? await renderer.render(component.template, context).data else { return nil }
        return String(buffer: buffer)
    }
}

struct DummyContext: Encodable
{
    let entry: DummyModel
}
