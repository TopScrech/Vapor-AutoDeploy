import Vapor
import Fluent
import Leaf
import LeafKit

extension Mist
{
    // Component Protocol Definition
    protocol Component
    {
        // Type representing the context data structure
        associatedtype Context: Encodable
        
        // unique identifier
        var name: String { get }
        
        // leaf template
        var template: String { get }
        
        // environment this component belongs to
        var environments: String { get }
                
        // Method to generate context for the template
        func context() -> Context
        
        // render method that returns the component's HTML
        func render(request: Request) async -> String?
    }
}

// Default implementation for common render functionality
extension Mist.Component
{
    var name: String { String(describing: Self.self) }
    var template: String { String(describing: Self.self) }
    
    func render(request: Request) async -> String?
    {
        do
        {
            let view: View = try await request.view.render(self.template, context())
            let body: String? = try await view.encodeResponse(status: .accepted, for: request).body.string
            
            return body
        }
        catch
        {
            return nil
        }
    }
}
