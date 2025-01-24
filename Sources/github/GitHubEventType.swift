import Vapor

extension GitHubEvent
{
    enum EventType: String
    {
        case push
        case test
    }
    
    struct Payload: Codable
    {
        let headCommit: Commit
        
        struct Commit: Codable
        {
            let id: String
            let author: Author
            let message: String
            let modified: [String]
            
            struct Author: Codable
            {
                let name: String
            }
        }
    }
}
