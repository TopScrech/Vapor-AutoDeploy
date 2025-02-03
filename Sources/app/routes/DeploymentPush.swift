import Vapor

extension Application
{
    func initiateDeployment(message: String?) async
    {
        // try to start deployment atomically
        let running = await DeploymentManager.shared.requestDeployment()
        
        // create deployment entry
        let deployment = Deployment(status: running ? "running" : "canceled", message: message ?? "")
        try? await deployment.save(on: self.db)
        
        // abort if deployment was canceled
        guard running else { return }
        
        // deploy ...
        do
        {
            // 1. git pull
            try await execute("git pull", step: 1)
            
            // 2. swift build
            try await execute("/usr/local/swift/usr/bin/swift build -c debug", step: 2)
            
            // 3. Move Executable
            try await moveExecutable()
            
            // deployment success
            deployment.status = "success"
            deployment.finishedAt = Date()
            try? await deployment.save(on: self.db)
            
            // unlock deployment pipeline
            await DeploymentManager.shared.endDeployment()
            
            // check for deployments that were canceled in the meantime
            if let latestCanceled = try await Deployment.query(on: self.db)
                .filter(\.$status, .equal, "canceled")
                .filter(\.$startedAt, .greaterThan, deployment.startedAt)
                .sort(\.$startedAt, .descending)
                .first()
            {
                // process latest canceled deployment
                await initiateDeployment(message: latestCanceled.message)
            }
            else
            {
                // restart if current deployment is up to date
                try await restart()
            }
        }
        catch
        {
            // deployment failed
            deployment.status = "failed"
            deployment.finishedAt = Date()
            try? await deployment.save(on: self.db)
            
            // unlock deployment pipeline
            await DeploymentManager.shared.endDeployment()
        }
    }
}

actor DeploymentManager
{
    static let shared = DeploymentManager()
    private(set) var isDeploying: Bool = false
    
    func requestDeployment() async -> Bool
    {
        guard !isDeploying else { return false }
        
        isDeploying = true
        return true
    }
    
    func endDeployment() async { isDeploying = false }
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
            await self.initiateDeployment(message: self.getCommitMessage(request))
        }
    }
}

// auto deploy commands
extension Application
{
    private func execute(_ command: String, step: Int) async throws
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
    
    private func restart() async throws
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
    
    private func getCommitMessage(_ request: Request) -> String?
    {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let bodyString = request.body.string,
              let jsonData = bodyString.data(using: .utf8),
              let payload = try? decoder.decode(DeploymentEvent.Payload.self, from: jsonData)
        else { return nil }
        
        return payload.headCommit.message
    }
    
    private func moveExecutable() async throws
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

