import Vapor
import Fluent

// mist component example
struct DummyRow: Mist.Component
{
    // implicit 1-to-1 relantionship of all models through common id
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}
