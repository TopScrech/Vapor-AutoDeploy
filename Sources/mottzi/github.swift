import Vapor

struct GitHubEvent
{
    let app: Application
    let type: EventType
    
    enum EventType: String
    {
        case push
        
        func formatLog(_ request: Request) -> String?
        {
            switch self
            {
                case .push: formatPushLog(request)
            }
        }
        
        private func formatPushLog(_ request: Request) -> String?
        {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            guard let bodyString = request.body.string,
                  let jsonData = bodyString.data(using: .utf8),
                  let payload = try? decoder.decode(GitHubEvent.Payload.self, from: jsonData)
            else { return nil }
            
            let log =
            [
                "Commit Details:",
                "----------------",
                "",
                "Author: \(payload.headCommit.author)",
                "Message: \(payload.headCommit.message)",
                "",
                !payload.headCommit.modified.isEmpty ? "Changed (\(payload.headCommit.modified.count): \(payload.headCommit.modified.joined(by: ", "))" : nil,
                !payload.headCommit.added.isEmpty ? "Added (\(payload.headCommit.added.count): \(payload.headCommit.added.joined(by: ", "))" : nil,
                !payload.headCommit.removed.isEmpty ? "Removed (\(payload.headCommit.removed.count): \(payload.headCommit.removed.joined(by: ", "))" : nil,
                "",
                "Commit URL: \(payload.headCommit.url)",
                "Compare-Link: \(payload.compare)",
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
            
            return log
        }
    }
    
    func listen(to endpoint: [PathComponent], action closure: @Sendable @escaping (Request) async -> Void)
    {
        let accepted = Response(status: .ok, body: .init(stringLiteral: "[mottzi] \(type.rawValue.capitalized) event request accepted."))
        let denied = Response(status: .forbidden, body: .init(stringLiteral: "[mottzi] \(type.rawValue.capitalized) event request denied."))
        
        app.post(endpoint)
        { request async -> Response in
            // validate request by verifying github signature header
            guard self.validateRequest(request) else { return denied }
            
            // Handle accepted request with custom action
            Task.detached { await closure(request) }
            
            // Respond immediately
            return accepted
        }
    }
    
    // verify that the request has a valid github signature LOL
    private func validateRequest(_ request: Request) -> Bool
    {
        if validateSignature(of: request)
        {
            var logContent =
            """
            =====================================================
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            Valid \(type.rawValue) event received [\(Date.now)]
            """
            
            if let commitContent = GitHubEvent.EventType.push.formatLog(request)
            {
                logContent += "\n\(commitContent)\n"
            }
            else
            {
                request.logger.error("Failed to format commit log details")
            }
            
            logContent +=
            """
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            =====================================================\n\n
            """
            
            return true
        }
        else
        {
            log("deploy/github/push.log",
            """
            =====================================================
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            Invalid \(type.rawValue) event received [\(Date.now)]
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            =====================================================\n\n
            """)
            
            return false
        }
    }
    
    // verify that the request has a valid github signature
    private func validateSignature(of request: Request) -> Bool
    {
        // hard coded secret *** SECURITY RISK ***
        let secret = "4133Pratteln"
        
        // get signature
        guard let signatureHeader = request.headers.first(name: "X-Hub-Signature-256") else { return false }
        
        // ensure signature starts with "sha256="
        guard signatureHeader.hasPrefix("sha256=") else { return false }
        
        // extract signature hex string
        let signatureHex = String(signatureHeader.dropFirst("sha256=".count))
        
        // get raw request body
        guard let payload = request.body.string else { return false }
        
        // encode local secret and received payload
        guard let payloadData = payload.data(using: .utf8),
              let secretData = secret.data(using: .utf8) else { return false }
        
        // calculate expected signature
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: SymmetricKey(data: secretData))
        
        let expectedSignatureHex = signature.map { String(format: "%02x", $0) }.joined()
        
        // constant-time comparison to prevent timing attacks
        guard expectedSignatureHex.count == signatureHex.count else { return false }
        
        let valid = HMAC<SHA256>.isValidAuthenticationCode(
            signatureHex.hexadecimal ?? Data(),
            authenticating: payloadData,
            using: SymmetricKey(data: secretData)
        )
        
        // request.logger.info("\(valid ? "Valid" : "Invalid") webhook received: \n\nheader: \(request.headers.description)\n\n payload: \(payload)")

        return valid
    }
}

extension Application
{
    // convenience function for use in application context lol
    func github(_ endpoint: PathComponent..., type: GitHubEvent.EventType, action closure: @Sendable @escaping (Request) async -> Void)
    {
        GitHubEvent(app: self, type: type).listen(to: endpoint, action: closure)
    }
}

extension String
{
    // needed for signature verification
    var hexadecimal: Data?
    {
        var data = Data(capacity: count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self))
        { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        return data
    }
}

extension GitHubEvent
{
    struct Payload: Codable
    {
        // Reference information
        let ref: String
        let before: String
        let after: String
        let baseRef: String?
        let compare: String
        
        // Core entities
        let repository: Repository
        let sender: User
        let pusher: Pusher
        
        // Commit information
        let commits: [Commit]
        let headCommit: Commit
        
        // Event metadata
        let created: Bool
        let deleted: Bool
        let forced: Bool
        
        struct Repository: Codable
        {
            // Core identifiers
            let id: Int
            let nodeId: String
            let name: String
            let fullName: String
            
            // Repository metadata
            let description: String?
            let isPrivate: Bool
            let fork: Bool
            let isTemplate: Bool
            let visibility: String
            let language: String?
            let license: String?
            
            // Statistics
            let size: Int
            let forksCount: Int
            let forks: Int
            let stargazersCount: Int
            let watchersCount: Int
            let watchers: Int
            let openIssuesCount: Int
            let openIssues: Int
            
            // Features and flags
            let hasIssues: Bool
            let hasProjects: Bool
            let hasDownloads: Bool
            let hasWiki: Bool
            let hasPages: Bool
            let hasDiscussions: Bool
            let allowForking: Bool
            let webCommitSignoffRequired: Bool
            let archived: Bool
            let disabled: Bool
            
            // URLs
            let url: String
            let htmlUrl: String
            let gitUrl: String
            let sshUrl: String
            let cloneUrl: String
            
            // Timestamps
            let createdAt: Int
            let updatedAt: String
            let pushedAt: Int
            
            // Relations
            let owner: User
            let defaultBranch: String
        }
        
        struct User: Codable
        {
            // Core identifiers
            let id: Int
            let nodeId: String
            let login: String
            
            // Profile information
            let type: String
            let userViewType: String
            let siteAdmin: Bool
            let gravatarId: String
            
            // URLs for user resources
            let url: String
            let htmlUrl: String
            let avatarUrl: String
            
            // API endpoints
            let followersUrl: String
            let followingUrl: String
            let gistsUrl: String
            let starredUrl: String
            let subscriptionsUrl: String
            let organizationsUrl: String
            let reposUrl: String
            let eventsUrl: String
            let receivedEventsUrl: String
        }
        
        struct Pusher: Codable
        {
            let name: String
            let email: String
        }
        
        struct Commit: Codable
        {
            // Core identifiers
            let id: String
            let treeId: String
            
            // Commit metadata
            let message: String
            let distinct: Bool
            let timestamp: String
            let url: String
            
            // Changes
            let added: [String]
            let removed: [String]
            let modified: [String]
            
            // Authors
            let author: CommitAuthor
            let committer: CommitAuthor
            
            struct CommitAuthor: Codable
            {
                let name: String
                let email: String
                let username: String
            }
        }
    }
}
