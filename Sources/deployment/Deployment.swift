import Vapor
import Fluent

// deployment model
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
    
    // returns array of all deployments, adjusted for presentation layer
    static func all(on database: Database) async throws -> [Deployment]
    {
        try await Deployment.query(on: database)
            .sort(\.$startedAt, .descending)
            .all()
            .markStaleDeployments()
            .markCurrentDeployment()
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

// cumputated model properties for presentaion layer
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

// functions to handle current deployment management
extension Deployment
{
    // flag this deployment as current
    func setCurrent(on database: Database) async throws
    {
        // clear any existing current deployments
        try await Deployment.clearCurrent(on: database)
        
        // set this one as current
        self.isCurrent = true
        
        // save change to db
        try await self.save(on: database)
    }
    
    // removes isCurrent flag of all entries that have it
    static func clearCurrent(on database: Database) async throws
    {
        try await Deployment.query(on: database)
            .set(\.$isCurrent, to: false)
            .filter(\.$isCurrent, .equal, true)
            .update()
    }
    
    // returns the current deployment
    static func current(on database: Database) async throws -> Deployment?
    {
        try await Deployment.query(on: database)
            .filter(\.$isCurrent, .equal, true)
            .first()
    }
}

// helper functions to adjust arrays of deployments for usage in presentation layer
extension Array where Element == Deployment
{
    // returns the array with all stale deployments marked as such
    func markStaleDeployments() -> [Deployment]
    {
        self.map()
        {
            // abort if deployment is not currently running
            guard $0.status == "running" else { return $0 }
            
            // abort if there is no start time
            guard let startedAt = $0.startedAt else { return $0 }
            
            // abort if minimal duration of deployment has not been reached
            guard Date().timeIntervalSince(startedAt) > 1800 else { return $0 }
            
            // if stale deployment was detected, flag it as such
            $0.status = "stale"
            
            return $0
        }
    }
    
    // returns the array with the currently deployed deployment marked as such
    func markCurrentDeployment() -> [Deployment]
    {
        self.map()
        {
            // abort if deployment is not last in pipe
            guard $0.isCurrent else { return $0 }
            
            // if latest deployment, mark as deployed on system
            $0.status = "deployed"
            
            return $0
        }
    }
}

// model encoding
extension Deployment
{
    enum CodingKeys: String, CodingKey
    {
        case id, status, message, isCurrent, startedAt, finishedAt
        case durationString, startedAtTimestamp
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
        try container.encode(message, forKey: .message)
        try container.encode(isCurrent, forKey: .isCurrent)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(finishedAt, forKey: .finishedAt)
        
        try container.encode(durationString, forKey: .durationString)
        try container.encode(startedAtTimestamp, forKey: .startedAtTimestamp)
    }
}
