import Vapor

extension GitHubEvent
{
    struct EventLog
    {
        var type: EventType
        var file: String
        var content = ""
        
        mutating func build(_ request: Request, valid: Bool)
        {
            var logContent = ""
            
            if valid
            {
                // +valid +details
                if let details = self.details(request, type)
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
                // +valid -details
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
            
            self.content = logContent
        }
        
        func write()
        {
            log("deploy/github/\(type.rawValue).log", content)
        }
        
        private func details(_ request: Request, _ type: EventType) -> String?
        {
            switch type
            {
                case .push: detailsPush(request)
                default: nil
            }
        }
        
        private func detailsPush(_ request: Request) -> String?
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
            
            log +=
            """
                Changed (\(payload.headCommit.modified.count)): 
                    - \(payload.headCommit.modified.joined(separator: ",\n        - "))"
            """
            
            return log
        }
    }
}

// appends content at the end of file
func log(_ filePath: String, _ content: String)
{
    // vapor logger
    let logger = Logger(label: "mottzi")
    
    // create log file if it does not exist
    if !FileManager.default.fileExists(atPath: filePath) {
        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
    }
    
    // abort if content data is empty
    guard let data = content.data(using: .utf8) else { return logger.debug("tried logging empty data") }
    
    do
    {
        // go to end of log file
        let file = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
        try file.seekToEnd()
        
        // write content to log file
        file.write(data)
        file.closeFile()
    }
    catch
    {
        logger.error("\(error.localizedDescription)")
    }
}
