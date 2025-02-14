import Vapor
import Fluent

// Basic component protocol - just needs to know its model type
protocol MistComponent
{
    static var name: String { get }
    static var model: String { get }
    static var template: String { get }
    
    static func html(renderer: ViewRenderer, model: any Model) async -> String?
}

extension MistComponent
{
    static func html(renderer: ViewRenderer, model: any Model) async -> String?
    {
        do
        {
            let view: View = try await renderer.render(self.template, model)
            return String(buffer: view.data)
        }
        catch
        {
            return nil
        }
    }
}

// Registry to maintain component <-> model relationships
actor MistComponentRegistry
{
    static let shared = MistComponentRegistry()
    public var renderer: ViewRenderer?
    
    private var modelComponents: [String: [any MistComponent.Type]] = [:]
    
    private init() { }
    
    func configure(renderer: ViewRenderer) {
        self.renderer = renderer
    }
    
    func register(_ component: any MistComponent.Type)
    {
        modelComponents[component.model, default: []].append(component)
    }
    
    func getComponents(forModel model: String) -> [any MistComponent.Type] {
        return modelComponents[model] ?? []
    }
}

struct DummyTableRowComponent: MistComponent
{
    static let name = "DummyRow"
    static let model = "DummyModel"
    static let template = "DummyRowHTML"
}

extension Mist
{
    static func configureComponents(_ app: Application)
    {
        Task
        {
            await MistComponentRegistry.shared.configure(renderer: app.leaf.renderer)
            await MistComponentRegistry.shared.register(DummyTableRowComponent.self)
        }
    }
}
