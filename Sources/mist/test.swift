import Vapor
import Fluent

struct Mist2 {}

extension Mist2
{
    actor Components
    {
        static let shared = Components()
        private init() { }
        
        private var components: [Component] = []
    }

    struct Component
    {
        let id: UUID
        let name: String
    }
}