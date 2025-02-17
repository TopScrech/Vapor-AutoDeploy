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
