import Vapor

actor DeploymentManager
{
    static let shared = DeploymentManager()
    init() { }
    
    var isDeploying: Bool = false
    
    func startDeployment() async
    {
        isDeploying = true
    }
    
    func endDeployment() async
    {
        isDeploying = false
    }
}

extension Application
{
    // auto deploy setup
    func usePushDeploy()
    {
        // github webhook push event route
        self.push("pushevent")
        { request async in
            // handle valid request
            await self.deploy(request)
        }
    }
    
    // handle valid push event
    private func deploy(_ request: Request) async
    {
        let block = await DeploymentManager.shared.isDeploying
        
        let commitInfo = getCommitInfo(request)
        let deployment = Deployment(status: block ? "canceled" : "running", message: commitInfo.message ?? "No message")
        try? await deployment.save(on: request.db)
        
        let logFile = "deploy/github/push.log"
        
        // log initial push event received with commit info
        var logContent =
        """
        =====================================================
        :::::::::::::::::::::::::::::::::::::::::::::::::::::
        Valid push event received [\(Date())]
        """
        
        if let commitLog = commitInfo.log
        {
            logContent += "\n\n\(commitLog)\n"
        }
        
        logContent +=
        """
        :::::::::::::::::::::::::::::::::::::::::::::::::::::
        =====================================================\n
        """
        
        log(logFile, logContent)
        log(logFile, block ? "\nCanceled:\n" : "\nAuto deploy:\n")
    
        if block
        {
            log(logFile,
            """
            \n=========================
            :::::::::::::::::::::::::
            Deployment process failed
            Error: Previous deployment still running
            :::::::::::::::::::::::::
            =========================\n\n
            """)
            
            return
        }
        
        await DeploymentManager.shared.startDeployment()
        
        do
        {
            // 1. Git Pull
            log(logFile, "\n> [1/4] Pulling repository\n")
            try await execute(command: "git pull", step: 1, logPath: logFile, deployment: deployment, request: request)
            
            // 2. Swift Build
            log(logFile, "\n> [2/4] Building app\n")
            try await execute(command: "/usr/local/swift/usr/bin/swift build -c debug", step: 2, logPath: logFile, deployment: deployment, request: request)
            
            // 3. Move Executable
            log(logFile, "\n> [3/4] Moving app .build/debug/ -> deploy/\n")
            try await moveExecutable(logPath: logFile, request: request)
            
            // 4. Finalize
            log(logFile, "\n> [4/4] Restarting app ...\n")
            
            log(logFile,
            """
            \nDeployment process completed
            ::::::::::::::::::::::::::::
            ============================\n\n
            """)
            
            // ... update deployment status
            deployment.status = "success"
            deployment.finishedAt = Date()
            try? await deployment.save(on: request.db)
            
            // unlock
            await DeploymentManager.shared.endDeployment()
            
            // ... restart app
            try await restart(request: request)
        }
        catch
        {
            log(logFile,
            """
            \n=========================
            :::::::::::::::::::::::::
            Deployment process failed
            Error: \(error.localizedDescription)
            :::::::::::::::::::::::::
            =========================\n\n
            """)
            
            // ... update deployment status
            deployment.status = "failed"
            deployment.finishedAt = Date()
            try? await deployment.save(on: request.db)
            
            // unlock
            await DeploymentManager.shared.endDeployment()
        }
    }
}

// auto deploy commands
extension Application
{
    private func execute(command: String, step: Int, logPath: String, deployment: Deployment, request: Request) async throws
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: "/var/www/mottzi")
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0
        {
            // why use NSError here specifically? error?
            throw NSError(domain: "DeploymentError", code: step, userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command)"])
        }
    }
    
    private func restart(request: Request) async throws
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["supervisorctl", "restart", "mottzi"]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0
        {
            throw Abort(.internalServerError, reason: "Failed to restart service")
        }
    }
    
    private func getCommitInfo(_ request: Request) -> (log: String?, author: String?, message: String?)
    {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let bodyString = request.body.string,
              let jsonData = bodyString.data(using: .utf8),
              let payload = try? decoder.decode(DeploymentEvent.Payload.self, from: jsonData)
        else { return (nil, nil, nil) }
        
        var commitInfo =
        """
        Commit:  \(payload.headCommit.id)
        Author:  \(payload.headCommit.author.name)
        Message: \(payload.headCommit.message)
        """
        
        if !payload.headCommit.modified.isEmpty
        {
            commitInfo +=
            """
            \n\nChanged (\(payload.headCommit.modified.count)):
                - \(payload.headCommit.modified.joined(separator: ",\n    - "))
            """
        }
        
        return (commitInfo, payload.headCommit.author.name, payload.headCommit.message)
    }
    
    private func moveExecutable(logPath: String, request: Request) async throws
    {
        let fileManager = FileManager.default
        let buildPath = "/var/www/mottzi/.build/debug/App"
        let deployPath = "/var/www/mottzi/deploy/App"
        
        do
        {
            try fileManager.createDirectory(atPath: "/var/www/mottzi/deploy", withIntermediateDirectories: true)
            
            if fileManager.fileExists(atPath: deployPath)
            {
                try fileManager.removeItem(atPath: deployPath)
            }
            
            try fileManager.moveItem(atPath: buildPath, toPath: deployPath)
        }
        catch
        {
            throw error
        }
    }
}

