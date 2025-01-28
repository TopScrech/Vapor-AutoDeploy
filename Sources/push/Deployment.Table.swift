import Fluent

extension Deployment
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(Deployment.schema)
                .id()
                .field("status", .string, .required)
                .field("log", .string, .required)
                .field("started_at", .datetime)
                .field("finished_at", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(Deployment.schema).delete()
        }
    }
    
    struct LogToMessage: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(Deployment.schema)
                .deleteField("log")
                .field("message", .string, .required)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Deployment.schema)
                .deleteField("message")
                .field("log", .string, .required)
                .update()
        }
    }
}
