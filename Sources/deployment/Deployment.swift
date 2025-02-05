import Vapor
import Fluent

// model
final class Deployment: Model, Content, @unchecked Sendable
{
    static let schema = "deployments"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "status") var status: String
    @Field(key: "message") var message: String
    @Timestamp(key: "started_at", on: .create) var startedAt: Date?
    @Timestamp(key: "finished_at", on: .none) var finishedAt: Date?
    
    init() {}
    
    init(status: String, message: String)
    {
        self.status = status
        self.message = message
    }
    
    static func all(on database: Database) async throws -> [Deployment]
    {
        try await self.query(on: database)
            .sort(\.$startedAt, .descending)
            .all()
            .stale()
    }
}

// cumputated properties
extension Deployment
{
    var durationString: String?
    {
        guard let finishedAt, let startedAt else { return nil }
        
        return String(format: "%.1fs", finishedAt.timeIntervalSince(startedAt))
    }
    
    var startedAtTimestamp: Double?
    {
        startedAt?.timeIntervalSince1970
    }
}

// encoding (cumputated properties)
extension Deployment
{
    enum CodingKeys: String, CodingKey
    {
        case id, status, message, startedAt, finishedAt
        case durationString, startedAtTimestamp
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
        try container.encode(message, forKey: .message)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(finishedAt, forKey: .finishedAt)
        
        try container.encode(durationString, forKey: .durationString)
        try container.encode(startedAtTimestamp, forKey: .startedAtTimestamp)
    }
}

// database table
extension Deployment
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(Deployment.schema)
                .id()
                .field("status", .string, .required)
                .field("message", .string, .required)
                .field("started_at", .datetime)
                .field("finished_at", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(Deployment.schema).delete()
        }
    }
}

// table listener
struct DeploymentListener: AsyncModelMiddleware
{
    func create(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        try await next.create(model, on: db)
        
        //let message = DeploymentClients.Message(.creation, model)
        let message = DeploymentMessage.create(payload: model)
        await DeploymentClients.shared.broadcast(message)
    }
    
    func update(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
    {
        try await next.update(model, on: db)
        
//        let message = DeploymentClients.Message(.update, model)
        let message = DeploymentMessage.update(payload: model)
        await DeploymentClients.shared.broadcast(message)
    }
}
