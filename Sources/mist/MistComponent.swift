import Vapor
import Fluent
import Leaf
import LeafKit

extension Mist
{
    // Component Protocol Definition
    protocol Component
    {
        // unique identifier
        var name: String { get }
        // leaf template
        var template: String { get }
        // environment this component belongs to
        var environments: String { get }
        
        // render method that returns the component's HTML
        func render(request: Request) async -> String?
    }
    
    // Example DummyComponent Implementation
    struct DummyComponent: Component
    {
        let environments: String
    }
}

// Default implementation for common render functionality
extension Mist.Component
{
    var name: String { String(describing: Self.self) }
    var template: String { String(describing: Self.self) }
    
    func render(request: Request) async -> String?
    {
        var view: View
        var body: String?
        
        do
        {
            view = try await request.view.render(self.template, ["hi":"hi"])
            body = try await view.encodeResponse(status: .accepted, for: request).body.string
        }
        catch
        {
            return nil
        }
        
        return body
    }
}
