import Vapor
import Fluent

// Basic component protocol - just needs to know its model type
protocol MistComponent
{
    associatedtype ModelType: Encodable
    
    static var name: String { get }
    static var model: String { get }
    static var template: String { get }
    
    static func html(renderer: ViewRenderer, model: ModelType) async -> String?
}

extension MistComponent
{
    static func html(renderer: ViewRenderer, model: ModelType) async -> String?
    {
        do
        {
            let buffer = try await renderer.render(self.template, ["entry": model]).data
            return String(buffer: buffer)
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
    
    func configure(renderer: ViewRenderer)
    {
        self.renderer = renderer
    }
    
    func register(_ component: any MistComponent.Type)
    {
        modelComponents[component.model, default: []].append(component)
    }
    
    func getComponents(forModel model: String) -> [any MistComponent.Type]
    {
        return modelComponents[model] ?? []
    }
}

struct DummyRowComponent: MistComponent
{
    typealias ModelType = DummyModel
    
    static let name = "DummyRow"
    static let model = "DummyModel"
    static let template = "DummyRow"
}

extension Mist
{
    static func configureComponents(_ app: Application)
    {
        Task
        {
            await MistComponentRegistry.shared.configure(renderer: app.leaf.renderer)
            
            await MistComponentRegistry.shared.register(DummyRowComponent.self)
        }
    }
}
