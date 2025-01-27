import Fluent

struct CreateDeploymentTask: AsyncMigration
{
    func prepare(on database: Database) async throws
    {
        try await database.schema(DeploymentTask.schema)
            .id()
            .field("status", .string, .required)
            .field("log", .string, .required)
            .field("started_at", .datetime)
            .field("finished_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws
    {
        try await database.schema(DeploymentTask.schema).delete()
    }
}
