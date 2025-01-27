import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

@main
struct mottzi
{
    static func main() async throws
    {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        
        app.databases.use(.sqlite(.file("deploy/github/deployments.db")), as: .sqlite)
        app.migrations.add(CreateDeploymentTask())
        try await app.autoMigrate()
        
        app.views.use(.leaf)
        app.useRoutes()
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}

extension Application
{
    // handle valid push event t
    func handlePushEvent(_ request: Request) async
    {
        let logFile = "deploy/github/push.log"
        
        // log initial push event received with commit info
        var logContent =
        """
        =====================================================
        :::::::::::::::::::::::::::::::::::::::::::::::::::::
        Valid push event received [\(Date())]
        """
        
        if let commitInfo = getCommitInfo(request)
        {
            logContent += "\n\n\(commitInfo)\n"
        }
        
        logContent +=
        """
        :::::::::::::::::::::::::::::::::::::::::::::::::::::
        =====================================================\n
        """
        
        log(logFile, logContent)
        
        // log deploy process beginning
        logContent = "\nAuto deploy:\n"
        
        let task = DeploymentTask(status: "running")
        try? await task.save(on: request.db)
        
        do
        {
            // 1. Git Pull
            log(logFile, "\n> [1/4] Pulling repository\n")
            try await execute(command: "git pull", step: 1, logPath: logFile, task: task, request: request)
            
            // 2. Swift Build
            log(logFile, "\n> [2/4] Building app\n")
            try await execute(command: "/usr/local/swift/usr/bin/swift build -c debug", step: 2, logPath: logFile, task: task, request: request)
            
            // 3. Move Executable
            log(logFile, "\n> [3/4] Moving app .build/debug/ -> deploy/\n")
            try await moveExecutable(logPath: logFile, task: task, request: request)
            
            // 4. Finalize
            log(logFile, "\n> [4/4] Deployment complete: ... restarting app ...\n")
            
            
            log(logFile,
            """
            \n============================
            ::::::::::::::::::::::::::::
            Deployment process completed
            ::::::::::::::::::::::::::::
            ============================\n\n
            """)
            
            // update deploy status
            task.status = "success"
            task.finishedAt = Date()
            try await task.save(on: request.db)
            
            // restart app
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
            
            task.status = "failed"
            task.finishedAt = Date()
            try? await task.save(on: request.db)
            return
        }
    }
    
    private func execute(command: String, step: Int, logPath: String, task: DeploymentTask, request: Request) async throws
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
    
    private func getCommitInfo(_ request: Request) -> String?
    {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let bodyString = request.body.string,
              let jsonData = bodyString.data(using: .utf8),
              let payload = try? decoder.decode(GitHubEvent.Payload.self, from: jsonData)
        else { return nil }
        
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
        
        return commitInfo
    }

    private func moveExecutable(logPath: String, task: DeploymentTask, request: Request) async throws
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
