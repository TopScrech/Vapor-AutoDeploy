@preconcurrency import Vapor
import Fluent
import Mist

final class DummyModel2: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels2"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text2") var text2: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(text: String)
    {
        self.text2 = text
    }
}

extension DummyModel2
{
    static func all(on database: Database) async throws -> [DummyModel2]
    {
        try await DummyModel2.query(on: database)
            .sort(\.$created, .descending)
            .all()
    }
}

// database table
extension DummyModel2
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(DummyModel2.schema)
                .id()
                .field("text2", .string, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(DummyModel2.schema).delete()
        }
    }
}
