import Vapor
import Fluent

final class Deployment: Model, Content
{
    static let schema = "deployments"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "status") var status: String // "running", "success", "failed"
    @Field(key: "log") var log: String
    @Timestamp(key: "started_at", on: .create) var startedAt: Date?
    @Timestamp(key: "finished_at", on: .none) var finishedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, status: String, log: String = "")
    {
        self.id = id
        self.status = status
        self.log = log
    }
}
