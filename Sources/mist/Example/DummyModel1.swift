@preconcurrency import Vapor
import Fluent
import Mist

final class DummyModel1: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text") var text: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    init(text: String) { self.text = text }
}

// database table
extension DummyModel1
{
    struct Table3: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema)
                .id()
                .field("text", .string, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema).delete()
        }
    }
}

extension DummyModel1
{
    static func all(on db: Database) async throws -> [DummyModel1]
    {
        try await DummyModel1.query(on: db)
            .sort(\.$created, .descending)
            .all()
    }
}
