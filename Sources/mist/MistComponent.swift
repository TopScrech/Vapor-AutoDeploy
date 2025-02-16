import Vapor
import Fluent

// MARK: - Core Component Protocol
protocol MistComponent<Model>
{
    associatedtype Model: Fluent.Model & Content
    
    static var name: ComponentName { get }
    static var template: TemplatePath { get }
    
    static func render(model: Model, using renderer: ViewRenderer) async throws -> String
}

// MARK: - Type-Safe Wrappers
struct ComponentName: RawRepresentable, Hashable
{
    let rawValue: String
    
    init(rawValue: String)
    {
        self.rawValue = rawValue
    }
    
    static func named(_ name: String) -> ComponentName
    {
        return ComponentName(rawValue: name)
    }
}

struct TemplatePath: RawRepresentable
{
    let rawValue: String
    
    init(rawValue: String)
    {
        self.rawValue = rawValue
    }
    
    static func path(_ path: String) -> TemplatePath
    {
        return TemplatePath(rawValue: path)
    }
}

// MARK: - Type-Safe Context
struct ComponentContext<T: Encodable>: Encodable
{
    // We need a coding key to match the original implementation's 'entry' key
    private enum CodingKeys: String, CodingKey
    {
        case model = "entry"
    }
    
    let model: T
    
    init(model: T)
    {
        self.model = model
    }
    
    // Implement custom encoding to match the original MistContext structure
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
    }
}
// MARK: - Default Implementation
extension MistComponent
{
    static func render(model: Model, using renderer: ViewRenderer) async throws -> String
    {
        let context = ComponentContext(model: model)
        let buffer = try await renderer.render(template.rawValue, context).data
        return String(buffer: buffer)
    }
}

// MARK: - Type-Safe Registry
extension Mist
{
    actor Components
    {
        // Singleton instance
        static let shared = Components()
        
        private init() { }
        
        // Type-safe storage using type erasure only at the storage level
        private var components: [String: [any ComponentRenderer]] = [:]
        
        private protocol ComponentRenderer
        {
            static func render(model: Any, using renderer: ViewRenderer) async throws -> String
            var componentType: any MistComponent.Type { get }
        }
        
        // Updated wrapper to hold static reference
        private struct AnyComponent<T: MistComponent>: ComponentRenderer
        {
            let componentType: any MistComponent.Type
            
            init(_ type: T.Type)
            {
                self.componentType = type
            }
            
            static func render(model: Any, using renderer: ViewRenderer) async throws -> String
            {
                guard let typedModel = model as? T.Model
                else
                {
                    throw Abort(.internalServerError, reason: "Model type mismatch")
                }
                
                return try await T.render(model: typedModel, using: renderer)
            }
        }
        
        // Updated registration to store component type
        func register<T: MistComponent>(_ component: T.Type)
        {
            let modelName = String(describing: T.Model.self)
            components[modelName, default: []].append(AnyComponent(component))
        }
        
        // Updated retrieval to return component types
        func getComponents<M: Fluent.Model & Content>(for modelType: M.Type) -> [any MistComponent.Type]
        {
            let modelName = String(describing: M.self)
            return components[modelName]?.map(\.componentType) ?? []
        }
        
        // Configured renderer
        public var renderer: ViewRenderer?
        
        func configure(renderer: ViewRenderer)
        {
            self.renderer = renderer
        }
    }
}

struct DummyRow: MistComponent
{
    typealias Model = DummyModel
    
    static var name: ComponentName = .named("DummyRow")
    static var template: TemplatePath = .path("DummyRow")
}

// MARK: - Configuration Extension
extension Mist
{
    static func configureComponents(_ app: Application)
    {
        // Run on app startup
        Task
        {
            await Mist.Components.shared.configure(renderer: app.leaf.renderer)
            await Mist.Components.shared.register(DummyRow.self)
        }
    }
}
