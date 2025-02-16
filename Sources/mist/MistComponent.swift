import Vapor
import Fluent

// Type-erasing wrapper for Encodable...
// what an abomination, mot modern at all.
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

// using type erasure... I hate this so much.
struct MistContext: Encodable
{
    let entry: AnyEncodable
    
    init(entry: any Encodable)
    {
        self.entry = AnyEncodable(entry)
    }
}

protocol MistComponent
{
    // should probably be intrinsicly bound to struct own name litral
    // otherwise String seems legit here
    static var name: String { get }
    
    // db model this component renders
    // in the future, we would want to make it possible that one component can have multiple models...
    // while the client uses String values, this should really be type safe ob swift backend.
    // since the model is literally in all cases a Fluent Model (final class DummyModel: Model, Content)
    // Content is Codable...
    static var model: String { get }
    
    // is a string by design
    static var template: String { get }
    
    // the html() function by default runs self.template trough leaf
    // using the appropriate context (which is of course dependant on the data model etc...)
    // and returns the String or nil
    static func html(renderer: ViewRenderer, model: any Encodable) async -> String?
}

extension MistComponent
{
    // default implementation
    static func html(renderer: ViewRenderer, model: any Encodable) async -> String?
    {
        do
        {
            // this context is highly model specific
            // each component should have its own intrinsic context definition
            let context = MistContext(entry: model)
            
            // render template with context
            let buffer = try await renderer.render(self.template, context).data
            return String(buffer: buffer)
        }
        catch
        {
            return nil
        }
    }
}

// Registry
extension Mist
{
    // thread safety
    actor Components
    {
        // singleton
        static let shared = Mist.Components()
        
        // provided through self.configure()
        public var renderer: ViewRenderer?
        func configure(renderer: ViewRenderer) { self.renderer = renderer }

        // stored registry data, using dictionaries
        // review if usage of 'any MistComponent.Type ' is correct
        private var modelComponents: [String: [any MistComponent.Type]] = [:]
        
        private init() { }
        
        // review if usage is correct
        func register(_ component: any MistComponent.Type)
        {
            modelComponents[component.model, default: []].append(component)
        }
        
        // review if usage is correct
        func getComponents(forModel model: String) -> [any MistComponent.Type]
        {
            return modelComponents[model] ?? []
        }
    }
}

// example component
struct DummyRow: MistComponent
{
    // uhhhh look at all the type unsafety
    // more instrucions look at protocol MistComponent definition comments
    static let name = "DummyRow"
    static let model = "DummyModel"
    static let template = "DummyRow"
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
