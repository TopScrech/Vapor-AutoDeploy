import Vapor
import Fluent
import Leaf
import LeafKit

// MARK: - Type-Safe Wrappers
struct ComponentName: RawRepresentable, Hashable, Sendable
{
    let rawValue: String
    
    init(rawValue: String)
    {
        self.rawValue = rawValue
    }
}

struct TemplatePath: RawRepresentable, Hashable, Sendable
{
    let rawValue: String
    
    init(rawValue: String)
    {
        self.rawValue = rawValue
    }
}

// MARK: - Type-Safe Context
struct ComponentContext<T: Encodable & Sendable>: Encodable, Sendable
{
    private enum CodingKeys: String, CodingKey
    {
        case model = "entry"
    }
    
    let model: T
    
    init(model: T)
    {
        self.model = model
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
    }
}

// MARK: - Core Component Protocol
protocol MistComponent<Model>: Sendable
{
    associatedtype Model: Fluent.Model & Content
    
    static var componentName: ComponentName { get }
    static var templatePath: TemplatePath { get }
}

// MARK: - Default Implementation
extension MistComponent
{
    static func render(model: Model, using renderer: any ViewRenderer) async throws -> String
    {
        let context = ComponentContext(model: model)
        let buffer = try await renderer.render(templatePath.rawValue, context).data
        return String(buffer: buffer)
    }
}

// MARK: - Type-Safe Registry
extension Mist
{
    actor Components
    {
        static let shared = Components()
        
        private var renderer: (any ViewRenderer & Sendable)?
        private var components: [String: [any ComponentRenderer]] = [:]
        
        private init() { }
        
        private protocol ComponentRenderer: Sendable
        {
            static func render(model: Any, using renderer: any ViewRenderer & Sendable) async throws -> String
            var componentType: any (MistComponent & Sendable).Type { get }
        }
        
        private struct AnyComponent<T: MistComponent>: ComponentRenderer
        {
            let componentType: any (MistComponent & Sendable).Type
            
            init(_ type: T.Type)
            {
                self.componentType = type
            }
            
            static func render(model: Any, using renderer: any ViewRenderer & Sendable) async throws -> String
            {
                guard let typedModel = model as? T.Model
                else
                {
                    throw Abort(.internalServerError, reason: "Model type mismatch")
                }
                
                return try await T.render(model: typedModel, using: renderer)
            }
        }
        
        func configure(renderer: any ViewRenderer & Sendable)
        {
            self.renderer = renderer
        }
        
        func register<T: MistComponent>(_ component: T.Type)
        {
            let modelName = String(describing: T.Model.self)
            components[modelName, default: []].append(AnyComponent(component))
        }
        
        func getComponents<M: Fluent.Model & Content>(for modelType: M.Type) -> [any (MistComponent & Sendable).Type]
        {
            let modelName = String(describing: M.self)
            return components[modelName]?.map(\.componentType) ?? []
        }
        
        func getRenderer() -> (any ViewRenderer & Sendable)?
        {
            return renderer
        }
    }
}

// MARK: - Example Component
struct DummyRow: MistComponent
{
    typealias Model = DummyModel
    
    static var componentName: ComponentName
    {
        return .init(rawValue: "DummyRow")
    }
    
    static var templatePath: TemplatePath
    {
        return .init(rawValue: "DummyRow")
    }
}
