//
//  Components.swift
//  mottzi
//
//  Created by Berken Sayilir on 17.02.2025.
//


// thread-safe component registry
extension Mist
{
    actor Components
    {
        // singleton instance
        static let shared = Components()
        private init() { }
        
        // store components by model type name
        private var components: [String: [AnyComponent]] = [:]
        private var renderer: ViewRenderer?
        
        // set template renderer
        func configure(renderer: ViewRenderer)
        {
            self.renderer = renderer
        }
        
        // register new component type
        func register<C: MistComponent>(_ component: C.Type)
        {
            let modelName = String(describing: C.Model.self)
            components[modelName, default: []].append(AnyComponent(component))
        }
        
        // get components that can render given model type
        func getComponents<M: Model & Content>(for type: M.Type) -> [AnyComponent]
        {
            let modelName = String(describing: M.self)
            return components[modelName] ?? []
        }
        
        // get configured renderer
        func getRenderer() -> ViewRenderer?
        {
            renderer
        }
    }
}