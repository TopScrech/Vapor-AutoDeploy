import Vapor
import Fluent

final class Deployment: Model, Content
{
    static let schema = "deployments"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "status") var status: String
    @Field(key: "message") var message: String
    @Timestamp(key: "started_at", on: .create) var startedAt: Date?
    @Timestamp(key: "finished_at", on: .none) var finishedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, status: String, message: String)
    {
        self.id = id
        self.status = status
        self.message = message
    }
}

// encoding for Leaf templates
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
    
    var durationString: String?
    {
        guard let finishedAt = finishedAt,
              let startedAt = startedAt
        else { return nil }
        
        return String(format: "%.1fs", finishedAt.timeIntervalSince(startedAt))
    }
    
    var startedAtTimestamp: Double
    {
        startedAt?.timeIntervalSince1970 ?? 0
    }
}
