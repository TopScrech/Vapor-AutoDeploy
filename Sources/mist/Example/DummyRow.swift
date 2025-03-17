import Vapor
import Fluent
import Mist

// mist component example
struct DummyRow: Mist.Component
{
    // implicit 1-to-1 relantionship of all models through common id
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    
    public static func makeContext(of componentID: UUID, in db: Database) async -> Mist.SingleComponentContext?
    {
        return nil
    }
    
    public static func makeContext(ofAll db: Database) async -> Mist.MultipleComponentContext?
    {
        return nil
    }
}
