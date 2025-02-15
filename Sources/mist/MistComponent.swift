import Vapor
import Fluent

// Type-erasing wrapper for Encodable values
struct AnyEncodable: Encodable
{
    private let _encode: (Encoder) throws -> Void
    
    init(_ value: any Encodable) {
        self._encode = { encoder in
            try value.encode(to: encoder)
        }
    }
    
    func encode(to encoder: Encoder) throws
    {
        try _encode(encoder)
    }
}

// Context structure that can handle type-erased Encodable values
struct MistContext: Encodable
{
    let entry: AnyEncodable
    
    init(entry: any Encodable)
    {
        self.entry = AnyEncodable(entry)
    }
}

// Basic component protocol - just needs to know its model type
protocol MistComponent
{
    static var name: String { get }
    static var model: String { get }
    static var template: String { get }
    
    static func html(renderer: ViewRenderer, model: any Encodable) async -> String?
}

extension MistComponent
{
    static func html(renderer: ViewRenderer, model: any Encodable) async -> String?
    {
        do
        {
            let context = MistContext(entry: model)
            let buffer = try await renderer.render(self.template, context).data
            return String(buffer: buffer)
        }
        catch
        {
            return nil
        }
    }
}

// Registry to maintain component <-> model relationships
extension Mist
{
    actor Components
    {
        static let shared = Mist.Components()
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
}

struct DummyRowComponent: MistComponent
{
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
            await Mist.Components.shared.configure(renderer: app.leaf.renderer)
            
            await Mist.Components.shared.register(DummyRowComponent.self)
        }
    }
}
