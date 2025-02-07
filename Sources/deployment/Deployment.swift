import Vapor
import Fluent

final class Deployment: Model, Content, @unchecked Sendable
{
    static let schema = "deployments"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "status") var status: String
    @Field(key: "message") var message: String
    @Field(key: "is_current") var isCurrent: Bool
    @Timestamp(key: "started_at", on: .create) var startedAt: Date?
    @Timestamp(key: "finished_at", on: .none) var finishedAt: Date?
    
    init() {}
    
    init(status: String, message: String)
    {
        self.status = status
        self.message = message
        self.isCurrent = false
    }
}

extension Deployment
{
    // set this deployment as current
    func setCurrent(on database: Database) async throws
    {
        // clear any existing current deployments
        try await Deployment.clearCurrent(on: database)
        
        // set this one as current
        self.isCurrent = true
        try await self.save(on: database)
    }
    
    // returns the current Deployment
    static func current(on database: Database) async throws -> Deployment?
    {
        try await Deployment.query(on: database)
            .filter(\.$isCurrent, .equal, true)
            .first()
    }
    
    static func clearCurrent(on database: Database) async throws
    {
        try await Deployment.query(on: database)
            .set(\.$isCurrent, to: false)
            .filter(\.$isCurrent, .equal, true)
            .update()
    }
    
    // returns array of all Deployments
    static func all(on database: Database) async throws -> [Deployment]
    {
        try await Deployment.query(on: database)
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

// encoding
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
                .field("is_current", .bool, .required, .sql(.default(false)))
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
extension Deployment
{
    struct Listener: AsyncModelMiddleware
    {
        func create(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            try await next.create(model, on: db)
            
            let message = Message.create(model)
            await DeploymentClients.shared.broadcast(message)
        }
        
        func update(model: Deployment, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            try await next.update(model, on: db)
            
            let message = Message.update(model)
            await DeploymentClients.shared.broadcast(message)
        }
    }
}
