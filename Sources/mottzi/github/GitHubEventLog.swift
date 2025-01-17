import Vapor

extension GitHubEvent.EventType
{
    // logs the
    func logRequest(_ request: Request, valid: Bool, type: Self)
    {
        var logContent = ""
        
        if valid
        {
            // valid + details
            if let details = type.detailsLogMessage(request)
            {
                logContent =
                """
                =====================================================
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                Valid \(type.rawValue) event received [\(Date.now)]
                    
                \(details)
                
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                =====================================================\n\n
                """
            }
            // valid - details
            else
            {
                logContent =
                """
                =====================================================
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                Valid \(type.rawValue) event received [\(Date.now)]
                :::::::::::::::::::::::::::::::::::::::::::::::::::::
                =====================================================\n\n
                """
            }
        }
        // invalid
        else
        {
            logContent =
            """
            =====================================================
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            Invalid \(type.rawValue) event received [\(Date.now)]
            :::::::::::::::::::::::::::::::::::::::::::::::::::::
            =====================================================\n\n
            """
        }
        
        log("deploy/github/\(type.rawValue).log", logContent)
    }
    
    func detailsLogMessage(_ request: Request) -> String?
    {
        switch self
        {
            case .push: detailsLogMessagePush(request)
            default: nil
        }
    }
    
    private func detailsLogMessagePush(_ request: Request) -> String?
    {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let bodyString = request.body.string,
              let jsonData = bodyString.data(using: .utf8),
              let payload = try? decoder.decode(GitHubEvent.Payload.self, from: jsonData)
        else { return nil }
        
        var log =
            """
                Commit:  \(payload.headCommit.id)
                Author:  \(payload.headCommit.author.name)
                Message: \(payload.headCommit.message)\n\n
            """
        
        guard !payload.headCommit.modified.isEmpty else { return log }
        let modified = payload.headCommit.modified.joined(separator: "")
        
        log +=
            """
                Changed (\(payload.headCommit.modified.count)): 
                    - \(payload.headCommit.modified.joined(separator: ",\n        - "))"
            """
        
        return log
    }
}
