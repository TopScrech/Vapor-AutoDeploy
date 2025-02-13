//
//  Component.swift
//  mottzi
//
//  Created by Berken Sayilir on 12.02.2025.
//


import Vapor
import Fluent
import Leaf
import LeafKit

extension Mist {
    // Component Protocol Definition
    protocol Component {
        // unique identifier
        var name: String { get }
        // leaf template
        var template: String { get }
        // environment this component belongs to
        var environments: String { get }
        
        // render method that returns the component's HTML
        func render(request: Request) async -> String?
    }
    
    // Default implementation for common render functionality
    extension Component {
        func render(request: Request) async -> String? {
            var view: View
            var body: String?
            
            do {
                view = try await request.view.render(self.template, ["hi":"hi"])
                body = try await view.encodeResponse(status: .accepted, for: request).body.string
            } catch {
                return nil
            }
            
            return body
        }
    }
    
    // Example DummyComponent Implementation
    struct DummyComponent: Component {
        let name: String
        let template: String
        let environments: String
        
        // Custom initializer
        init(name: String, environments: String) {
            self.name = name
            self.template = "dummy"  // Points to a dummy.leaf template
            self.environments = environments
        }
        
        // Optional: Override render method if needed
        func render(request: Request) async -> String? {
            // Custom rendering logic could go here
            // For now, we'll use the default implementation
            return await super.render(request: request)
        }
    }
}